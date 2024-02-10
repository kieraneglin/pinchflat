defmodule Pinchflat.Tasks.SourceTasks do
  @moduledoc """
  This module contains methods for managing tasks (workers) related to sources.
  """

  alias Pinchflat.Media
  alias Pinchflat.Tasks
  alias Pinchflat.MediaSource.Source
  alias Pinchflat.MediaClient.SourceDetails
  alias Pinchflat.Workers.MediaIndexingWorker
  alias Pinchflat.Workers.VideoDownloadWorker

  @doc """
  Starts tasks for indexing a source's media.

  Returns {:ok, :should_not_index} | {:ok, %Task{}}.
  """
  def kickoff_indexing_task(%Source{} = source) do
    Tasks.delete_pending_tasks_for(source)

    if source.index_frequency_minutes <= 0 do
      {:ok, :should_not_index}
    else
      source
      |> Map.take([:id])
      # Schedule this one immediately, but future ones will be on an interval
      |> MediaIndexingWorker.new()
      |> Tasks.create_job_with_task(source)
      |> case do
        # This should never return {:error, :duplicate_job} since we just deleted
        # any pending tasks. I'm being assertive about it so it's obvious if I'm wrong
        {:ok, task} -> {:ok, task}
      end
    end
  end

  @doc """
  Given a media source, creates (indexes) the media by creating media_items for each
  media ID in the source.

  Returns [%MediaItem{}, ...] | [%Ecto.Changeset{}, ...]
  """
  def index_media_items(%Source{} = source) do
    {:ok, media_attributes} = SourceDetails.get_media_attributes(source.original_url)

    media_attributes
    |> Enum.map(fn media_attrs ->
      attrs = %{
        source_id: source.id,
        title: media_attrs["title"],
        media_id: media_attrs["id"],
        original_url: media_attrs["original_url"],
        livestream: media_attrs["was_live"]
      }

      case Media.create_media_item(attrs) do
        {:ok, media_item} -> media_item
        {:error, changeset} -> changeset
      end
    end)
  end

  @doc """
  Starts tasks for downloading videos for any of a sources _pending_ media items.
  Jobs are not enqueued if the source is set to not download media. This will return :ok.

  NOTE: this starts a download for each media item that is pending,
  not just the ones that were indexed in this job run. This should ensure
  that any stragglers are caught if, for some reason, they weren't enqueued
  or somehow got de-queued.

  I'm not sure of a case where this would happen, but it's cheap insurance.

  Returns :ok
  """
  def enqueue_pending_media_tasks(%Source{download_media: true} = source) do
    source
    |> Media.list_pending_media_items_for()
    |> Enum.each(fn media_item ->
      media_item
      |> Map.take([:id])
      |> VideoDownloadWorker.new()
      |> Tasks.create_job_with_task(media_item)
    end)
  end

  def enqueue_pending_media_tasks(%Source{download_media: false} = _source) do
    :ok
  end

  @doc """
  Deletes ALL pending tasks for a source's media items.

  Returns :ok
  """
  def dequeue_pending_media_tasks(%Source{} = source) do
    source
    |> Media.list_pending_media_items_for()
    |> Enum.each(&Tasks.delete_pending_tasks_for/1)
  end
end
