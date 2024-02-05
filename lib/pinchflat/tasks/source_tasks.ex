defmodule Pinchflat.Tasks.SourceTasks do
  @moduledoc """
  This module contains methods for managing tasks (workers) related to sources.
  """

  alias Pinchflat.Media
  alias Pinchflat.Tasks
  alias Pinchflat.MediaSource.Source
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
  Starts tasks for downloading videos for any of a sources _pending_ media items.

  NOTE: this starts a download for each media item that is pending,
  not just the ones that were indexed in this job run. This should ensure
  that any stragglers are caught if, for some reason, they weren't enqueued
  or somehow got de-queued.

  I'm not sure of a case where this would happen, but it's cheap insurance.

  Returns :ok
  """
  def enqueue_pending_media_downloads(%Source{} = source) do
    source
    |> Media.list_pending_media_items_for()
    |> Enum.each(fn media_item ->
      media_item
      |> Map.take([:id])
      |> VideoDownloadWorker.new()
      |> Tasks.create_job_with_task(media_item)
    end)
  end
end
