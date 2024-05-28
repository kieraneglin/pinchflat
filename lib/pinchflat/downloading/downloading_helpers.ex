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

  alias Pinchflat.Lifecycle.UserScripts.CommandRunner, as: UserScriptRunner

  @doc """
  Starts tasks for downloading media for any of a sources _pending_ media items.
  Jobs are not enqueued if the source is set to not download media. This will return :ok.

  You can optionally set the `kickoff_delay` option to delay when the jobs are enqueued.

  NOTE: this starts a download for each media item that is pending,
  not just the ones that were indexed in this job run. This should ensure
  that any stragglers are caught if, for some reason, they weren't enqueued
  or somehow got de-queued.

  Returns :ok
  """
  def enqueue_pending_download_tasks(source, opts \\ [])

  def enqueue_pending_download_tasks(%Source{download_media: true} = source, opts) do
    kickoff_delay = Keyword.get(opts, :kickoff_delay, 0)

    source
    |> Media.list_pending_media_items_for()
    |> Enum.each(&MediaDownloadWorker.kickoff_with_task(&1, %{}, schedule_in: kickoff_delay))
  end

  def enqueue_pending_download_tasks(%Source{download_media: false}, _opts) do
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

  You can optionally set the `kickoff_delay` option to delay when the jobs are enqueued.

  Returns {:ok, %Task{}} | {:error, :should_not_download} | {:error, any()}
  """
  def kickoff_download_if_pending(%MediaItem{} = media_item, opts \\ []) do
    kickoff_delay = Keyword.get(opts, :kickoff_delay, 0)
    media_item = Repo.preload(media_item, :source)

    if media_item.source.download_media && Media.pending_download?(media_item) do
      Logger.info("Kicking off download for media item ##{media_item.id} (#{media_item.media_id})")

      MediaDownloadWorker.kickoff_with_task(media_item, %{}, schedule_in: kickoff_delay)
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
          not (^MediaQuery.download_prevented()) and
          not (^MediaQuery.culled())
      )
    )
    |> Repo.all()
    |> Enum.map(&MediaDownloadWorker.kickoff_with_task/1)
  end

  @doc """
  Creates a media item from the attributes returned by the video backend
  (read: yt-dlp) and runs the user script with a `media_indexed` event type.

  Only runs the user script if the media item was created successfully and the media item
  doesn't already exist in the database.

  Returns {:ok, %MediaItem{}} | {:error, any()}
  """
  def create_media_item_and_run_script(%Source{} = source, media_attrs_struct) do
    media_already_exists =
      MediaQuery.new()
      |> where(^dynamic(^MediaQuery.for_source(source) and ^MediaQuery.media_id(media_attrs_struct.media_id)))
      |> Repo.exists?()

    case Media.create_media_item_from_backend_attrs(source, media_attrs_struct) do
      {:ok, media_item} ->
        if !media_already_exists do
          UserScriptRunner.run(:media_indexed, media_item)
        end

        {:ok, media_item}

      err ->
        err
    end
  end
end
