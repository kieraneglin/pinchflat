defmodule Pinchflat.MediaSource do
  @moduledoc """
  The MediaSource context.
  """

  import Ecto.Query, warn: false
  alias Pinchflat.Repo

  alias Pinchflat.Tasks
  alias Pinchflat.Media
  alias Pinchflat.Tasks.ChannelTasks
  alias Pinchflat.MediaSource.Source
  alias Pinchflat.MediaClient.ChannelDetails

  @doc """
  Returns the list of channels. Returns [%Source{}, ...]
  """
  def list_sources do
    Repo.all(Source)
  end

  @doc """
  Gets a single channel.

  Returns %Source{}. Raises `Ecto.NoResultsError` if the Channel does not exist.
  """
  def get_source!(id), do: Repo.get!(Source, id)

  @doc """
  Creates a channel. May attempt to pull additional channel details from the
  original_url (if provided). Will attempt to start indexing the channel's
  media if successfully inserted.

  Returns {:ok, %Source{}} | {:error, %Ecto.Changeset{}}
  """
  def create_source(attrs) do
    %Source{}
    |> change_source_from_url(attrs)
    |> commit_and_start_indexing()
  end

  @doc """
  Given a media source, creates (indexes) the media by creating media_items for each
  media ID in the source.

  Returns [%MediaItem{}, ...] | [%Ecto.Changeset{}, ...]
  """
  def index_media_items(%Source{} = source) do
    {:ok, media_ids} = ChannelDetails.get_video_ids(source.original_url)

    media_ids
    |> Enum.map(fn media_id ->
      attrs = %{source_id: source.id, media_id: media_id}

      case Media.create_media_item(attrs) do
        {:ok, media_item} -> media_item
        {:error, changeset} -> changeset
      end
    end)
  end

  @doc """
  Updates a channel. May attempt to pull additional channel details from the
  original_url (if changed). May attempt to start indexing the channel's
  media if the indexing frequency has been changed.

  Existing indexing tasks will be cancelled if the indexing frequency has been
  changed (logic in `ChannelTasks.kickoff_indexing_task`)

  Returns {:ok, %Source{}} | {:error, %Ecto.Changeset{}}
  """
  def update_source(%Source{} = channel, attrs) do
    channel
    |> change_source_from_url(attrs)
    |> commit_and_start_indexing()
  end

  @doc """
  Deletes a channel and it's associated tasks (of any state).

  Returns {:ok, %Source{}} | {:error, %Ecto.Changeset{}}
  """
  def delete_source(%Source{} = channel) do
    Tasks.delete_tasks_for(channel)
    Repo.delete(channel)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking channel changes.
  """
  def change_source(%Source{} = channel, attrs \\ %{}) do
    Source.changeset(channel, attrs)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking channel changes and additionally
  fetches channel details from the original_url (if provided). If the channel
  details cannot be fetched, an error is added to the changeset.

  Note that this fetches channel details as long as the `original_url` is present.
  This means that it'll go for it even if a changeset is otherwise invalid. This
  is pretty easy to change, but for MVP I'm not concerned.
  """
  def change_source_from_url(%Source{} = channel, attrs) do
    case change_source(channel, attrs) do
      %Ecto.Changeset{changes: %{original_url: _}} = changeset ->
        add_source_details_to_changeset(channel, changeset)

      changeset ->
        changeset
    end
  end

  defp add_source_details_to_changeset(channel, changeset) do
    %Ecto.Changeset{changes: changes} = changeset

    case ChannelDetails.get_source_details(changes.original_url) do
      {:ok, %ChannelDetails{} = channel_details} ->
        change_source(
          channel,
          Map.merge(changes, %{
            name: channel_details.name,
            collection_id: channel_details.id
          })
        )

      {:error, runner_error, _status_code} ->
        Ecto.Changeset.add_error(
          changeset,
          :original_url,
          "could not fetch channel details from URL",
          error: runner_error
        )
    end
  end

  defp commit_and_start_indexing(changeset) do
    case Repo.insert_or_update(changeset) do
      {:ok, %Source{} = channel} ->
        maybe_run_indexing_task(changeset, channel)

        {:ok, channel}

      err ->
        err
    end
  end

  defp maybe_run_indexing_task(changeset, channel) do
    case changeset.data do
      # If the changeset is new (not persisted), attempt indexing no matter what
      %{__meta__: %{state: :built}} ->
        ChannelTasks.kickoff_indexing_task(channel)

      # If the record has been persisted, only attempt indexing if the
      # indexing frequency has been changed
      %{__meta__: %{state: :loaded}} ->
        if Map.has_key?(changeset.changes, :index_frequency_minutes) do
          ChannelTasks.kickoff_indexing_task(channel)
        end
    end
  end
end
