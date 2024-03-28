defmodule Pinchflat.Sources do
  @moduledoc """
  The Sources context.
  """

  import Ecto.Query, warn: false
  alias Pinchflat.Repo

  alias Pinchflat.Media
  alias Pinchflat.Tasks
  alias Pinchflat.Sources.Source
  alias Pinchflat.Media.MediaQuery
  alias Pinchflat.Profiles.MediaProfile
  alias Pinchflat.YtDlp.MediaCollection
  alias Pinchflat.Metadata.SourceMetadata
  alias Pinchflat.Filesystem.FilesystemHelpers
  alias Pinchflat.Downloading.DownloadingHelpers
  alias Pinchflat.FastIndexing.FastIndexingWorker
  alias Pinchflat.SlowIndexing.SlowIndexingHelpers
  alias Pinchflat.Metadata.SourceMetadataStorageWorker

  @doc """
  Returns the list of sources. Returns [%Source{}, ...]
  """
  def list_sources do
    Repo.all(Source)
  end

  @doc """
  Returns the list of sources for a media_profile.

  Returns [%Source{}, ...]
  """
  def list_sources_for(%MediaProfile{} = media_profile) do
    Repo.all(from s in Source, where: s.media_profile_id == ^media_profile.id)
  end

  @doc """
  Gets a single source.

  Returns %Source{}. Raises `Ecto.NoResultsError` if the Source does not exist.
  """
  def get_source!(id), do: Repo.get!(Source, id)

  @doc """
  Creates a source. May attempt to pull additional source details from the
  original_url (if provided). Will attempt to start indexing the source's
  media if successfully inserted.

  Runs an initial `change_source` check to ensure most of the source is valid
  before making an expensive API call. Runs it through `Repo.insert` even
  though we know it's going to fail so it picks up any addl. database errors
  and fulfills our return contract.

  You can pass options to control the behavior of the function:
    - `run_post_commit_tasks` (default: true) - If false, the function will not
      enqueue any tasks in `commit_and_handle_tasks`.

  Returns {:ok, %Source{}} | {:error, %Ecto.Changeset{}}
  """
  def create_source(attrs, opts \\ []) do
    case change_source(%Source{}, attrs, :initial) do
      %Ecto.Changeset{valid?: true} ->
        %Source{}
        |> maybe_change_source_from_url(attrs)
        |> maybe_change_indexing_frequency()
        |> commit_and_handle_tasks(opts)

      changeset ->
        Repo.insert(changeset)
    end
  end

  @doc """
  Updates a source. May attempt to pull additional source details from the
  original_url (if changed). May attempt to start indexing the source's
  media if the indexing frequency has been changed.

  Existing indexing tasks will be cancelled if the indexing frequency has been
  changed (logic in `SlowIndexingHelpers.kickoff_indexing_task`)

  Runs an initial `change_source` check to ensure most of the source is valid
  before making an expensive API call. Runs it through `Repo.update` even
  though we know it's going to fail so it picks up any addl. database errors
  and fulfills our return contract.

  You can pass options to control the behavior of the function:
    - `run_post_commit_tasks` (default: true) - If false, the function will not
      enqueue any tasks in `commit_and_handle_tasks`.

  Returns {:ok, %Source{}} | {:error, %Ecto.Changeset{}}
  """
  def update_source(%Source{} = source, attrs, opts \\ []) do
    case change_source(source, attrs, :initial) do
      %Ecto.Changeset{valid?: true} ->
        source
        |> maybe_change_source_from_url(attrs)
        |> maybe_change_indexing_frequency()
        |> commit_and_handle_tasks(opts)

      changeset ->
        Repo.update(changeset)
    end
  end

  @doc """
  Deletes a source, its media items, and its associated tasks (of any state).
  Can optionally delete the source's media files.

  Returns {:ok, %Source{}} | {:error, %Ecto.Changeset{}}
  """
  def delete_source(%Source{} = source, opts \\ []) do
    delete_files = Keyword.get(opts, :delete_files, false)
    Tasks.delete_tasks_for(source)

    MediaQuery.new()
    |> MediaQuery.for_source(source)
    |> Repo.all()
    |> Enum.each(fn media_item ->
      Media.delete_media_item(media_item, delete_files: delete_files)
    end)

    if delete_files do
      delete_source_files(source)
    end

    delete_internal_metadata_files(source)
    Repo.delete(source)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking source changes.
  """
  def change_source(%Source{} = source, attrs \\ %{}, validation_stage \\ :pre_insert) do
    Source.changeset(source, attrs, validation_stage)
  end

  # NOTE: When operating in the ideal path, this effectively adds an API call
  # to the source creation/update process. Should be used only when needed.
  defp maybe_change_source_from_url(%Source{} = source, attrs) do
    case change_source(source, attrs) do
      %Ecto.Changeset{changes: %{original_url: _}} = changeset ->
        add_source_details_to_changeset(source, changeset)

      changeset ->
        changeset
    end
  end

  defp delete_source_files(source) do
    mapped_struct = Map.from_struct(source)

    Source.filepath_attributes()
    |> Enum.map(fn field -> mapped_struct[field] end)
    |> Enum.filter(&is_binary/1)
    |> Enum.each(&FilesystemHelpers.delete_file_and_remove_empty_directories/1)
  end

  defp delete_internal_metadata_files(source) do
    metadata = Repo.preload(source, :metadata).metadata || %SourceMetadata{}
    mapped_struct = Map.from_struct(metadata)

    SourceMetadata.filepath_attributes()
    |> Enum.map(fn field -> mapped_struct[field] end)
    |> Enum.filter(&is_binary/1)
    |> Enum.each(&FilesystemHelpers.delete_file_and_remove_empty_directories/1)
  end

  defp add_source_details_to_changeset(source, changeset) do
    case MediaCollection.get_source_details(changeset.changes.original_url) do
      {:ok, source_details} ->
        add_source_details_by_collection_type(source, changeset, source_details)

      {:error, runner_error, _status_code} ->
        Ecto.Changeset.add_error(
          changeset,
          :original_url,
          "could not fetch source details from URL",
          error: runner_error
        )
    end
  end

  defp add_source_details_by_collection_type(source, changeset, source_details) do
    %Ecto.Changeset{changes: changes} = changeset

    collection_changes =
      if source_details.playlist_id == source_details.channel_id do
        %{
          collection_type: :channel,
          collection_id: source_details.channel_id,
          collection_name: source_details.channel_name
        }
      else
        %{
          collection_type: :playlist,
          collection_id: source_details.playlist_id,
          collection_name: source_details.playlist_name
        }
      end

    change_source(source, Map.merge(changes, collection_changes))
  end

  defp maybe_change_indexing_frequency(changeset) do
    fast_index = Ecto.Changeset.get_field(changeset, :fast_index)

    if fast_index do
      Ecto.Changeset.put_change(
        changeset,
        :index_frequency_minutes,
        Source.index_frequency_when_fast_indexing()
      )
    else
      changeset
    end
  end

  defp commit_and_handle_tasks(changeset, opts) do
    run_post_commit_tasks = Keyword.get(opts, :run_post_commit_tasks, true)

    case Repo.insert_or_update(changeset) do
      {:ok, %Source{} = source} ->
        if run_post_commit_tasks do
          maybe_handle_media_tasks(changeset, source)
          maybe_run_indexing_task(changeset, source)
          run_metadata_storage_task(source)
        end

        {:ok, source}

      err ->
        err
    end
  end

  # If the source is NOT new (ie: updated) and the download_media flag has changed,
  # enqueue or dequeue media download tasks as necessary.
  defp maybe_handle_media_tasks(changeset, source) do
    case {changeset.data, changeset.changes} do
      {%{__meta__: %{state: :loaded}}, %{download_media: true}} ->
        DownloadingHelpers.enqueue_pending_download_tasks(source)

      {%{__meta__: %{state: :loaded}}, %{download_media: false}} ->
        DownloadingHelpers.dequeue_pending_download_tasks(source)

      _ ->
        :ok
    end
  end

  defp maybe_run_indexing_task(changeset, source) do
    case changeset.data do
      # If the changeset is new (not persisted), attempt indexing no matter what
      %{__meta__: %{state: :built}} ->
        SlowIndexingHelpers.kickoff_indexing_task(source)

      # If the record has been persisted, only run indexing if the
      # indexing frequency has been changed and is now greater than 0
      %{__meta__: %{state: :loaded}} ->
        maybe_update_slow_indexing_task(changeset, source)
        maybe_update_fast_indexing_task(changeset, source)
    end
  end

  # This runs every time to pick up any changes to the metadata
  defp run_metadata_storage_task(source) do
    SourceMetadataStorageWorker.kickoff_with_task(source)
  end

  defp maybe_update_slow_indexing_task(changeset, source) do
    case changeset.changes do
      %{index_frequency_minutes: mins} when mins > 0 ->
        SlowIndexingHelpers.kickoff_indexing_task(source)

      %{index_frequency_minutes: _} ->
        Tasks.delete_pending_tasks_for(source, "FastIndexingWorker")
        Tasks.delete_pending_tasks_for(source, "MediaIndexingWorker")
        Tasks.delete_pending_tasks_for(source, "MediaCollectionIndexingWorker")

      _ ->
        :ok
    end
  end

  defp maybe_update_fast_indexing_task(changeset, source) do
    case changeset.changes do
      %{fast_index: true} ->
        Tasks.delete_pending_tasks_for(source, "FastIndexingWorker")
        FastIndexingWorker.kickoff_with_task(source)

      %{fast_index: false} ->
        Tasks.delete_pending_tasks_for(source, "FastIndexingWorker")

      _ ->
        :ok
    end
  end
end
