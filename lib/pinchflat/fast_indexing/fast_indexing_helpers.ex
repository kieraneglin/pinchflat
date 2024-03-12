defmodule Pinchflat.FastIndexing.FastIndexingHelpers do
  alias Pinchflat.Media
  alias Pinchflat.Tasks
  alias Pinchflat.Sources
  alias Pinchflat.Sources.Source
  alias Pinchflat.FastIndexing.YoutubeRss
  alias Pinchflat.Media.MediaItem
  alias Pinchflat.FastIndexing.FastIndexingWorker
  alias Pinchflat.Downloading.MediaDownloadWorker
  alias Pinchflat.FastIndexing.MediaIndexingWorker
  alias Pinchflat.YtDlp.Backend.MediaCollection
  alias Pinchflat.SlowIndexing.MediaCollectionIndexingWorker
  alias Pinchflat.Utils.FilesystemUtils.FileFollowerServer

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

  Despite the similar name to `kickoff_fast_indexing_task`, this does work differently.
  `kickoff_fast_indexing_task` starts a task that _calls_ this function whereas this
  function starts individual indexing tasks for each new media item. I think it does
  make sense grammatically, but I could see how that's confusing.

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
end
