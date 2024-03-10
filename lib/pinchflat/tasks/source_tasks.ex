defmodule Pinchflat.Tasks.SourceTasks do
  @moduledoc """
  Contains methods used by OR used to create/manage tasks for sources.

  Tasks/workers are meant to be thin wrappers so most of the actual work they
  do is also defined here. Essentially, a one-stop-shop for source-related tasks/workers.
  """

  require Logger

  alias Pinchflat.Media
  alias Pinchflat.Tasks
  alias Pinchflat.Sources
  alias Pinchflat.Sources.Source
  alias Pinchflat.Api.YoutubeRss
  alias Pinchflat.Media.MediaItem
  alias Pinchflat.Workers.FastIndexingWorker
  alias Pinchflat.Workers.MediaDownloadWorker
  alias Pinchflat.Workers.MediaIndexingWorker
  alias Pinchflat.YtDlp.Backend.MediaCollection
  alias Pinchflat.Workers.MediaCollectionIndexingWorker
  alias Pinchflat.Utils.FilesystemUtils.FileFollowerServer

  alias Pinchflat.YtDlp.Backend.Media, as: YtDlpMedia

  @doc """
  Starts tasks for indexing a source's media regardless of the source's indexing
  frequency. It's assumed the caller will check for indexing frequency.

  Returns {:ok, %Task{}}.
  """
  def kickoff_indexing_task(%Source{} = source) do
    Tasks.delete_pending_tasks_for(source, "FastIndexingWorker")
    Tasks.delete_pending_tasks_for(source, "MediaIndexingWorker")
    Tasks.delete_pending_tasks_for(source, "MediaCollectionIndexingWorker")

    %{id: source.id}
    # Schedule this one immediately, but future ones will be on an interval
    |> MediaCollectionIndexingWorker.new()
    |> Tasks.create_job_with_task(source)
  end

  @doc """
  Starts tasks for running a fast indexing task for a source's media
  regardless of the source's fast_index state. It's assumed the
  caller will check for fast_index.

  This is used for running fast index tasks on update. On creation, the
  fast index is enqueued after the slow index is complete.

  Returns {:ok, %Task{}}.
  """
  def kickoff_fast_indexing_task(%Source{} = source) do
    Tasks.delete_pending_tasks_for(source, "FastIndexingWorker")

    %{id: source.id}
    # Schedule this one immediately, but future ones will be on an interval
    |> FastIndexingWorker.new()
    |> Tasks.create_job_with_task(source)
  end

  @doc """
  Fetches new media IDs from a source's YouTube RSS feed and kicks off indexing tasks
  for any new media items. See comments in `MediaIndexingWorker` for more info on the
  order of operations and how this fits into the indexing process.

  Returns :ok
  """
  def kickoff_indexing_tasks_from_youtube_rss_feed(%Source{} = source) do
    {:ok, media_ids} = YoutubeRss.get_recent_media_ids_from_rss(source)
    existing_media_items = Media.list_media_items_by_media_id_for(source, media_ids)
    new_media_ids = media_ids -- Enum.map(existing_media_items, & &1.media_id)

    Enum.each(new_media_ids, fn media_id ->
      url = "https://www.youtube.com/watch?v=#{media_id}"

      %{id: source.id, media_url: url}
      |> MediaIndexingWorker.new()
      |> Tasks.create_job_with_task(source)
    end)
  end

  @doc """
  Given a media source, creates (indexes) the media by creating media_items for each
  media ID in the source. Afterward, kicks off a download task for each pending media
  item belonging to the source. You can't tell me the method name isn't descriptive!

  Indexing is slow and usually returns a list of all media data at once for record creation.
  To help with this, we use a file follower to watch the file that yt-dlp writes to
  so we can create media items as they come in. This parallelizes the process and adds
  clarity to the user experience. This has a few things to be aware of which are documented
  below in the file watcher setup method.

  NOTE: downloads are only enqueued if the source is set to download media. Downloads are
  also enqueued for ALL pending media items, not just the ones that were indexed in this
  job run. This should ensure that any stragglers are caught if, for some reason, they
  weren't enqueued or somehow got de-queued.

  Since indexing returns all media data EVERY TIME, we rely on the unique index of the
  media_id to prevent duplicates. Due to both the file follower and the fact that future
  indexing will index a lot of existing data, this method will MOSTLY return error
  changesets (from the unique index violation) and not media items. This is intended.

  Returns [%MediaItem{}, ...] | [%Ecto.Changeset{}, ...]
  """
  def index_and_enqueue_download_for_media_items(%Source{} = source) do
    # See the method definition below for more info on how file watchers work
    # (important reading if you're not familiar with it)
    {:ok, media_attributes} = get_media_attributes_for_collection_and_setup_file_watcher(source)
    result = Enum.map(media_attributes, fn media_attrs -> create_media_item_from_attributes(source, media_attrs) end)

    Sources.update_source(source, %{last_indexed_at: DateTime.utc_now()})
    enqueue_pending_media_tasks(source)

    result
  end

  @doc """
  Starts tasks for downloading media for any of a sources _pending_ media items.
  Jobs are not enqueued if the source is set to not download media. This will return :ok.

  NOTE: this starts a download for each media item that is pending,
  not just the ones that were indexed in this job run. This should ensure
  that any stragglers are caught if, for some reason, they weren't enqueued
  or somehow got de-queued.

  Returns :ok
  """
  def enqueue_pending_media_tasks(%Source{download_media: true} = source) do
    source
    |> Media.list_pending_media_items_for()
    |> Enum.each(fn media_item ->
      %{id: media_item.id}
      |> MediaDownloadWorker.new()
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
    maybe_media_item = create_media_item_from_attributes(source, media_attrs)

    case maybe_media_item do
      %MediaItem{} = media_item ->
        if source.download_media && Media.pending_download?(media_item) do
          Logger.debug("FileFollowerServer Handler: Enqueuing download task for #{inspect(media_attrs)}")

          %{id: media_item.id}
          |> MediaDownloadWorker.new()
          |> Tasks.create_job_with_task(media_item)
        end

      changeset ->
        changeset
    end
  end

  defp create_media_item_from_attributes(source, media_attrs) do
    case Media.create_media_item_from_backend_attrs(source, media_attrs) do
      {:ok, media_item} -> media_item
      {:error, changeset} -> changeset
    end
  end
end
