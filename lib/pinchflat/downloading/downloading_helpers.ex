defmodule Pinchflat.Downloading.DownloadingHelpers do
  @moduledoc """
  Methods for helping download media

  Many of these methods are made to be kickoff or be consumed by workers.
  """

  require Logger

  alias Pinchflat.Media
  alias Pinchflat.Tasks
  alias Pinchflat.Sources.Source
  alias Pinchflat.Downloading.MediaDownloadWorker

  @doc """
  Starts tasks for downloading media for any of a sources _pending_ media items.
  Jobs are not enqueued if the source is set to not download media. This will return :ok.

  NOTE: this starts a download for each media item that is pending,
  not just the ones that were indexed in this job run. This should ensure
  that any stragglers are caught if, for some reason, they weren't enqueued
  or somehow got de-queued.

  Returns :ok
  """
  def enqueue_pending_download_tasks(%Source{download_media: true} = source) do
    source
    |> Media.list_pending_media_items_for()
    |> Enum.each(&MediaDownloadWorker.kickoff_with_task/1)
  end

  def enqueue_pending_download_tasks(%Source{download_media: false}) do
    :ok
  end

  @doc """
  Deletes ALL pending tasks for a source's media items.

  Returns :ok
  """
  def dequeue_pending_download_tasks(%Source{} = source) do
    source
    |> Media.list_pending_media_items_for()
    |> Enum.each(&Tasks.delete_pending_tasks_for/1)
  end
end
