defmodule Pinchflat.SlowIndexing.SlowIndexingHelpers do
  @moduledoc """
  Methods for performing slow indexing tasks and managing the indexing process.

  Many of these methods are made to be kickoff or be consumed by workers.
  """

  require Logger

  alias Pinchflat.Media
  alias Pinchflat.Tasks
  alias Pinchflat.Sources
  alias Pinchflat.Sources.Source
  alias Pinchflat.Media.MediaItem
  alias Pinchflat.YtDlp.MediaCollection
  alias Pinchflat.Downloading.DownloadingHelpers
  alias Pinchflat.SlowIndexing.FileFollowerServer
  alias Pinchflat.Downloading.MediaDownloadWorker
  alias Pinchflat.SlowIndexing.MediaCollectionIndexingWorker

  alias Pinchflat.YtDlp.Media, as: YtDlpMedia

  @doc """
  Starts tasks for indexing a source's media regardless of the source's indexing
  frequency. It's assumed the caller will check for indexing frequency.

  Returns {:ok, %Task{}}.
  """
  def kickoff_indexing_task(%Source{} = source) do
    Tasks.delete_pending_tasks_for(source, "FastIndexingWorker")
    Tasks.delete_pending_tasks_for(source, "MediaIndexingWorker")
    Tasks.delete_pending_tasks_for(source, "MediaCollectionIndexingWorker")

    MediaCollectionIndexingWorker.kickoff_with_task(source)
  end

  @doc """
  Given a media source, creates (indexes) the media by creating media_items for each
  media ID in the source. Afterward, kicks off a download task for each pending media
  item belonging to the source. You can't tell me the method name isn't descriptive!
  Returns a list of media items or changesets (if the media item couldn't be created).

  Indexing is slow and usually returns a list of all media data at once for record creation.
  To help with this, we use a file follower to watch the file that yt-dlp writes to
  so we can create media items as they come in. This parallelizes the process and adds
  clarity to the user experience. This has a few things to be aware of which are documented
  below in the file watcher setup method.

  NOTE: downloads are only enqueued if the source is set to download media. Downloads are
  also enqueued for ALL pending media items, not just the ones that were indexed in this
  job run. This should ensure that any stragglers are caught if, for some reason, they
  weren't enqueued or somehow got de-queued.

  Since indexing returns all media data EVERY TIME, we that that opportunity to update
  indexing metadata for media items that have already been created.

  Returns [%MediaItem{} | %Ecto.Changeset{}]
  """
  def index_and_enqueue_download_for_media_items(%Source{} = source) do
    # See the method definition below for more info on how file watchers work
    # (important reading if you're not familiar with it)
    {:ok, media_attributes} = get_media_attributes_for_collection_and_setup_file_watcher(source)

    result =
      Enum.map(media_attributes, fn media_attrs ->
        case Media.create_media_item_from_backend_attrs(source, media_attrs) do
          {:ok, media_item} -> media_item
          {:error, changeset} -> changeset
        end
      end)

    Sources.update_source(source, %{last_indexed_at: DateTime.utc_now()})
    DownloadingHelpers.enqueue_pending_download_tasks(source)

    result
  end

  # The file follower is a GenServer that watches a file for new lines and
  # processes them. This works well, but we have to be resilliant to partially-written
  # lines (ie: you should gracefully fail if you can't parse a line).
  #
  # This works in-tandem with the normal (blocking) media indexing behaviour. When
  # the `get_media_attributes_for_collection` method completes it'll return the FULL result to
  # the caller for parsing. Ideally, every item in the list will have already
  # been processed by the file follower, but if not, the caller handles creation
  # of any media items that were missed/initially failed.
  #
  # It attempts a graceful shutdown of the file follower after the indexing is done,
  # but the FileFollowerServer will also stop itself if it doesn't see any activity
  # for a sufficiently long time.
  defp get_media_attributes_for_collection_and_setup_file_watcher(source) do
    {:ok, pid} = FileFollowerServer.start_link()

    handler = fn filepath -> setup_file_follower_watcher(pid, filepath, source) end
    result = MediaCollection.get_media_attributes_for_collection(source.original_url, file_listener_handler: handler)

    FileFollowerServer.stop(pid)

    result
  end

  defp setup_file_follower_watcher(pid, filepath, source) do
    FileFollowerServer.watch_file(pid, filepath, fn line ->
      case Phoenix.json_library().decode(line) do
        {:ok, media_attrs} ->
          Logger.debug("FileFollowerServer Handler: Got media attributes: #{inspect(media_attrs)}")

          media_struct = YtDlpMedia.response_to_struct(media_attrs)
          create_media_item_and_enqueue_download(source, media_struct)

        err ->
          Logger.debug("FileFollowerServer Handler: Error decoding JSON: #{inspect(err)}")

          err
      end
    end)
  end

  defp create_media_item_and_enqueue_download(source, media_attrs) do
    case Media.create_media_item_from_backend_attrs(source, media_attrs) do
      {:ok, %MediaItem{} = media_item} ->
        if source.download_media && Media.pending_download?(media_item) do
          Logger.debug("FileFollowerServer Handler: Enqueuing download task for #{inspect(media_attrs)}")

          MediaDownloadWorker.kickoff_with_task(media_item)
        end

      {:error, changeset} ->
        changeset
    end
  end
end
