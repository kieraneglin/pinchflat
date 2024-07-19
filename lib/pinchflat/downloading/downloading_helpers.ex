defmodule Pinchflat.Downloading.DownloadingHelpers do
  @moduledoc """
  Methods for helping download media

  Many of these methods are made to be kickoff or be consumed by workers.
  """

  require Logger

  use Pinchflat.Media.MediaQuery

  alias Pinchflat.Repo
  alias Pinchflat.Media
  alias Pinchflat.Tasks
  alias Pinchflat.Sources.Source
  alias Pinchflat.Media.MediaItem
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

  @doc """
  Takes a single media item and enqueues a download job if the media should be
  downloaded, based on the source's download settings and whether media is
  considered pending.

  Returns {:ok, %Task{}} | {:error, :should_not_download} | {:error, any()}
  """
  def kickoff_download_if_pending(%MediaItem{} = media_item) do
    media_item = Repo.preload(media_item, :source)

    if media_item.source.download_media && Media.pending_download?(media_item) do
      Logger.info("Kicking off download for media item ##{media_item.id} (#{media_item.media_id})")

      MediaDownloadWorker.kickoff_with_task(media_item)
    else
      {:error, :should_not_download}
    end
  end

  @doc """
  For a given source, enqueues download jobs for all media items _that have already been downloaded_.

  This is useful for when a source's download settings have changed and you want to run through all
  existing media and retry the download. For instance, if the source didn't originally download thumbnails
  and you've changed the source to download them, you can use this to download all the thumbnails for
  existing media items.

  NOTE: does not delete existing files whatsoever. Does not overwrite the existing media file if it exists
  at the location it expects. Will cause a full redownload of everything if the output template has changed

  NOTE: unrelated to the MediaQualityUpgradeWorker, which is for redownloading media items for quality upgrades
  or improved sponsorblock segments

  Returns [{:ok, %Task{}} | {:error, any()}]
  """
  def kickoff_redownload_for_existing_media(%Source{} = source) do
    MediaQuery.new()
    |> MediaQuery.require_assoc(:media_profile)
    |> where(
      ^dynamic(
        [m, s, mp],
        ^MediaQuery.for_source(source) and
          ^MediaQuery.downloaded() and
          not (^MediaQuery.download_prevented())
      )
    )
    |> Repo.all()
    |> Enum.map(&MediaDownloadWorker.kickoff_with_task/1)
  end
end
