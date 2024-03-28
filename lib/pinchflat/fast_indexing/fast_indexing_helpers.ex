defmodule Pinchflat.FastIndexing.FastIndexingHelpers do
  @moduledoc """
  Methods for performing fast indexing tasks and managing the fast indexing process.

  Many of these methods are made to be kickoff or be consumed by workers.
  """

  alias Pinchflat.Repo
  alias Pinchflat.Media
  alias Pinchflat.Sources.Source
  alias Pinchflat.Media.MediaQuery
  alias Pinchflat.FastIndexing.YoutubeRss
  alias Pinchflat.Downloading.MediaDownloadWorker
  alias Pinchflat.FastIndexing.MediaIndexingWorker

  alias Pinchflat.YtDlp.Media, as: YtDlpMedia

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
    existing_media_items = list_media_items_by_media_id_for(source, media_ids)
    new_media_ids = media_ids -- Enum.map(existing_media_items, & &1.media_id)

    Enum.each(new_media_ids, fn media_id ->
      url = "https://www.youtube.com/watch?v=#{media_id}"

      MediaIndexingWorker.kickoff_with_task(source, url)
    end)
  end

  @doc """
  Indexes a single media item for a source and enqueues a download job if the
  media should be downloaded. This method creates the media item record so it's
  the one-stop-shop for adding a media item (and possibly downloading it) just
  by a URL and source.

  Returns {:ok, media_item} | {:error, any()}
  """
  def index_and_enqueue_download_for_media_item(%Source{} = source, url) do
    maybe_media_item = create_media_item_from_url(source, url)

    case maybe_media_item do
      {:ok, media_item} ->
        if source.download_media && Media.pending_download?(media_item) do
          MediaDownloadWorker.kickoff_with_task(media_item)
        end

        {:ok, media_item}

      err ->
        err
    end
  end

  defp list_media_items_by_media_id_for(source, media_ids) do
    MediaQuery.new()
    |> MediaQuery.for_source(source)
    |> MediaQuery.with_media_ids(media_ids)
    |> Repo.all()
  end

  defp create_media_item_from_url(source, url) do
    {:ok, media_attrs} = YtDlpMedia.get_media_attributes(url)

    Media.create_media_item_from_backend_attrs(source, media_attrs)
  end
end
