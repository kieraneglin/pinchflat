defmodule Pinchflat.Sources do
  @moduledoc """
  The Sources context.
  """

  import Ecto.Query, warn: false
  alias Pinchflat.Repo

  alias Pinchflat.Media
  alias Pinchflat.Tasks
  alias Pinchflat.Tasks.SourceTasks
  alias Pinchflat.Sources.Source
  alias Pinchflat.MediaClient.SourceDetails

  @doc """
  Returns the list of sources. Returns [%Source{}, ...]
  """
  def list_sources do
    Repo.all(Source)
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

  Returns {:ok, %Source{}} | {:error, %Ecto.Changeset{}}
  """
  def create_source(attrs) do
    %Source{}
    |> change_source_from_url(attrs)
    |> commit_and_handle_tasks()
  end

  @doc """
  Updates a source. May attempt to pull additional source details from the
  original_url (if changed). May attempt to start indexing the source's
  media if the indexing frequency has been changed.

  Existing indexing tasks will be cancelled if the indexing frequency has been
  changed (logic in `SourceTasks.kickoff_indexing_task`)

  Returns {:ok, %Source{}} | {:error, %Ecto.Changeset{}}
  """
  def update_source(%Source{} = source, attrs) do
    source
    |> change_source_from_url(attrs)
    |> commit_and_handle_tasks()
  end

  @doc """
  Deletes a source, its media items, and its associated tasks (of any state).
  Can optionally delete the source's media files.

  Returns {:ok, %Source{}} | {:error, %Ecto.Changeset{}}
  """
  def delete_source(%Source{} = source, opts \\ []) do
    delete_files = Keyword.get(opts, :delete_files, false)

    source
    |> Media.list_media_items_for()
    |> Enum.each(fn media_item ->
      Media.delete_media_item(media_item, delete_files: delete_files)
    end)

    Tasks.delete_tasks_for(source)
    Repo.delete(source)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking source changes.
  """
  def change_source(%Source{} = source, attrs \\ %{}) do
    Source.changeset(source, attrs)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking source changes and additionally
  fetches source details from the original_url (if provided). If the source
  details cannot be fetched, an error is added to the changeset.

  Note that this fetches source details as long as the `original_url` is present.
  This means that it'll go for it even if a changeset is otherwise invalid. This
  is pretty easy to change, but for MVP I'm not concerned.

  NOTE: When operating in the ideal path, this effectively adds an API call
  to the source creation/update process. Should be used only when needed.
  """
  def change_source_from_url(%Source{} = source, attrs) do
    case change_source(source, attrs) do
      %Ecto.Changeset{changes: %{original_url: _}} = changeset ->
        add_source_details_to_changeset(source, changeset)

      changeset ->
        changeset
    end
  end

  defp add_source_details_to_changeset(source, changeset) do
    %Ecto.Changeset{changes: changes} = changeset

    case SourceDetails.get_source_details(changes.original_url) do
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

  defp commit_and_handle_tasks(changeset) do
    case Repo.insert_or_update(changeset) do
      {:ok, %Source{} = source} ->
        maybe_handle_media_tasks(changeset, source)
        maybe_run_indexing_task(changeset, source)

      err ->
        err
    end
  end

  # If the source is NOT new (ie: updated) and the download_media flag has changed,
  # enqueue or dequeue media download tasks as necessary.
  defp maybe_handle_media_tasks(changeset, source) do
    case {changeset.data, changeset.changes} do
      {%{__meta__: %{state: :loaded}}, %{download_media: true}} ->
        SourceTasks.enqueue_pending_media_tasks(source)

      {%{__meta__: %{state: :loaded}}, %{download_media: false}} ->
        SourceTasks.dequeue_pending_media_tasks(source)

      _ ->
        :ok
    end

    {:ok, source}
  end

  # IDEA: this uses a pattern where `kickoff_indexing_task` controls whether
  # it should run based on the source, but `maybe_handle_media_tasks` handles that
  # logic itself. Consider updating one or the other to be consistent (once I've
  # decided which I like more)
  defp maybe_run_indexing_task(changeset, source) do
    case changeset.data do
      # If the changeset is new (not persisted), attempt indexing no matter what
      %{__meta__: %{state: :built}} ->
        SourceTasks.kickoff_indexing_task(source)

      # If the record has been persisted, only attempt indexing if the
      # indexing frequency has been changed
      %{__meta__: %{state: :loaded}} ->
        if Map.has_key?(changeset.changes, :index_frequency_minutes) do
          SourceTasks.kickoff_indexing_task(source)
        end
    end

    {:ok, source}
  end
end
