defmodule Pinchflat.FastIndexing.FastIndexingHelpers do
  @moduledoc """
  Methods for performing fast indexing tasks and managing the fast indexing process.

  Many of these methods are made to be kickoff or be consumed by workers.
  """

  require Logger

  use Pinchflat.Media.MediaQuery

  alias Pinchflat.Repo
  alias Pinchflat.Media
  alias Pinchflat.Sources.Source
  alias Pinchflat.FastIndexing.YoutubeRss
  alias Pinchflat.Downloading.DownloadingHelpers

  alias Pinchflat.YtDlp.Media, as: YtDlpMedia

  @doc """
  Fetches new media IDs from a source's YouTube RSS feed, indexes them, and kicks off downloading
  tasks for any pending media items. See comments in `FastIndexingWorker` for more info on the
  order of operations and how this fits into the indexing process.

  Returns [%MediaItem{}] where each item is a new media item that was created _but not necessarily
  downloaded_.
  """
  def kickoff_download_tasks_from_youtube_rss_feed(%Source{} = source) do
    {:ok, media_ids} = YoutubeRss.get_recent_media_ids(source)
    existing_media_items = list_media_items_by_media_id_for(source, media_ids)
    new_media_ids = media_ids -- Enum.map(existing_media_items, & &1.media_id)

    maybe_new_media_items =
      Enum.map(new_media_ids, fn media_id ->
        case create_media_item_from_media_id(source, media_id) do
          {:ok, media_item} ->
            media_item

          err ->
            Logger.error("Error creating media item '#{media_id}' from URL: #{inspect(err)}")
            nil
        end
      end)

    DownloadingHelpers.enqueue_pending_download_tasks(source)

    Enum.filter(maybe_new_media_items, & &1)
  end

  defp list_media_items_by_media_id_for(source, media_ids) do
    MediaQuery.new()
    |> where(^dynamic([mi], ^MediaQuery.for_source(source) and mi.media_id in ^media_ids))
    |> Repo.all()
  end

  defp create_media_item_from_media_id(source, media_id) do
    url = "https://www.youtube.com/watch?v=#{media_id}"

    case YtDlpMedia.get_media_attributes(url) do
      {:ok, media_attrs} ->
        Media.create_media_item_from_backend_attrs(source, media_attrs)

      err ->
        err
    end
  end
end
