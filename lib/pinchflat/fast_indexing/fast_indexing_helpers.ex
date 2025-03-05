defmodule Pinchflat.FastIndexing.FastIndexingHelpers do
  @moduledoc """
  Methods for performing fast indexing tasks and managing the fast indexing process.

  Many of these methods are made to be kickoff or be consumed by workers.
  """

  require Logger

  use Pinchflat.Media.MediaQuery

  alias Pinchflat.Repo
  alias Pinchflat.Media
  alias Pinchflat.Tasks
  alias Pinchflat.Sources
  alias Pinchflat.Sources.Source
  alias Pinchflat.FastIndexing.YoutubeRss
  alias Pinchflat.FastIndexing.YoutubeApi
  alias Pinchflat.Downloading.DownloadingHelpers
  alias Pinchflat.FastIndexing.FastIndexingWorker
  alias Pinchflat.Downloading.DownloadOptionBuilder

  alias Pinchflat.YtDlp.Media, as: YtDlpMedia

  @doc """
  Kicks off a new fast indexing task for a source. This will delete any existing fast indexing
  tasks for the source before starting a new one.

  Returns {:ok, %Task{}}
  """
  def kickoff_indexing_task(%Source{} = source) do
    Tasks.delete_pending_tasks_for(source, "FastIndexingWorker", include_executing: true)
    FastIndexingWorker.kickoff_with_task(source)
  end

  @doc """
  Fetches new media IDs for a source from YT's API or RSS, indexes them, and kicks off downloading
  tasks for any pending media items. See comments in `FastIndexingWorker` for more info on the
  order of operations and how this fits into the indexing process.

  Returns [%MediaItem{}] where each item is a new media item that was created _but not necessarily
  downloaded_.
  """
  def index_and_kickoff_downloads(%Source{} = source) do
    # The media_profile is needed to determine the quality options to _then_ determine a more
    # accurate predicted filepath
    source = Repo.preload(source, [:media_profile])

    {:ok, media_ids} = get_recent_media_ids(source)
    existing_media_items = list_media_items_by_media_id_for(source, media_ids)
    new_media_ids = media_ids -- Enum.map(existing_media_items, & &1.media_id)

    maybe_new_media_items =
      Enum.map(new_media_ids, fn media_id ->
        case create_media_item_from_media_id(source, media_id) do
          {:ok, media_item} ->
            DownloadingHelpers.kickoff_download_if_pending(media_item, priority: 0)
            media_item

          err ->
            Logger.error("Error creating media item '#{media_id}' from URL: #{inspect(err)}")
            nil
        end
      end)

    # Pick up any stragglers. Intentionally has a lower priority than the per-media item
    # kickoff above
    DownloadingHelpers.enqueue_pending_download_tasks(source, priority: 1)

    Enum.filter(maybe_new_media_items, & &1)
  end

  # If possible, use the YouTube API to fetch media IDs. If that fails, fall back to the RSS feed.
  # If the YouTube API isn't set up, just use the RSS feed.
  defp get_recent_media_ids(source) do
    with true <- YoutubeApi.enabled?(),
         {:ok, media_ids} <- YoutubeApi.get_recent_media_ids(source) do
      {:ok, media_ids}
    else
      _ -> YoutubeRss.get_recent_media_ids(source)
    end
  end

  defp list_media_items_by_media_id_for(source, media_ids) do
    MediaQuery.new()
    |> where(^dynamic([mi], ^MediaQuery.for_source(source) and mi.media_id in ^media_ids))
    |> Repo.all()
  end

  defp create_media_item_from_media_id(source, media_id) do
    url = "https://www.youtube.com/watch?v=#{media_id}"
    # This is set to :metadata instead of :indexing since this happens _after_ the
    # actual indexing process. In reality, slow indexing is the only thing that
    # should be using :indexing.
    should_use_cookies = Sources.use_cookies?(source, :metadata)

    command_opts =
      [output: DownloadOptionBuilder.build_output_path_for(source)] ++
        DownloadOptionBuilder.build_quality_options_for(source)

    case YtDlpMedia.get_media_attributes(url, command_opts, use_cookies: should_use_cookies) do
      {:ok, media_attrs} ->
        Media.create_media_item_from_backend_attrs(source, media_attrs)

      err ->
        err
    end
  end
end
