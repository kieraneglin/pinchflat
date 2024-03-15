defmodule Pinchflat.FastIndexing.FastIndexingHelpersTest do
  use Pinchflat.DataCase

  import Mox
  import Pinchflat.MediaFixtures
  import Pinchflat.SourcesFixtures
  import Pinchflat.ProfilesFixtures

  alias Pinchflat.Tasks
  alias Pinchflat.Media.MediaItem
  alias Pinchflat.Downloading.MediaDownloadWorker
  alias Pinchflat.FastIndexing.MediaIndexingWorker
  alias Pinchflat.FastIndexing.FastIndexingHelpers

  setup :verify_on_exit!

  @media_url "https://www.youtube.com/watch?v=test_1"

  describe "kickoff_indexing_tasks_from_youtube_rss_feed/1" do
    setup do
      {:ok, [source: source_fixture()]}
    end

    test "enqueues a new worker for each new media_id in the source's RSS feed", %{source: source} do
      expect(HTTPClientMock, :get, fn _url -> {:ok, "<yt:videoId>test_1</yt:videoId>"} end)

      assert :ok = FastIndexingHelpers.kickoff_indexing_tasks_from_youtube_rss_feed(source)

      assert [worker] = all_enqueued(worker: MediaIndexingWorker)
      assert worker.args["id"] == source.id
      assert worker.args["media_url"] == "https://www.youtube.com/watch?v=test_1"
    end

    test "does not enqueue a new worker for the source's media IDs we already know about", %{source: source} do
      expect(HTTPClientMock, :get, fn _url -> {:ok, "<yt:videoId>test_1</yt:videoId>"} end)
      media_item_fixture(source_id: source.id, media_id: "test_1")

      assert :ok = FastIndexingHelpers.kickoff_indexing_tasks_from_youtube_rss_feed(source)

      refute_enqueued(worker: MediaIndexingWorker)
    end
  end

  describe "index_and_enqueue_download_for_media_item/2" do
    setup do
      stub(YtDlpRunnerMock, :run, fn _url, _opts, _ot ->
        {:ok, media_attributes_return_fixture()}
      end)

      {:ok, [source: source_fixture()]}
    end

    test "creates a new media item based on the URL", %{source: source} do
      assert Repo.aggregate(MediaItem, :count) == 0
      assert {:ok, _} = FastIndexingHelpers.index_and_enqueue_download_for_media_item(source, @media_url)
      assert Repo.aggregate(MediaItem, :count) == 1
    end

    test "won't duplicate media_items based on media_id and source", %{source: source} do
      assert {:ok, mi_1} = FastIndexingHelpers.index_and_enqueue_download_for_media_item(source, @media_url)
      assert {:ok, mi_2} = FastIndexingHelpers.index_and_enqueue_download_for_media_item(source, @media_url)

      assert Repo.aggregate(MediaItem, :count) == 1
      assert mi_1.id == mi_2.id
    end

    test "enqueues a download job", %{source: source} do
      assert {:ok, media_item} = FastIndexingHelpers.index_and_enqueue_download_for_media_item(source, @media_url)

      assert_enqueued(worker: MediaDownloadWorker, args: %{"id" => media_item.id})
    end

    test "creates a download task record", %{source: source} do
      assert {:ok, media_item} = FastIndexingHelpers.index_and_enqueue_download_for_media_item(source, @media_url)

      assert [_] = Tasks.list_tasks_for(media_item, "MediaDownloadWorker")
    end

    test "does not enqueue a download job if the source does not allow it" do
      source = source_fixture(%{download_media: false})

      assert {:ok, _} = FastIndexingHelpers.index_and_enqueue_download_for_media_item(source, @media_url)

      refute_enqueued(worker: MediaDownloadWorker)
    end

    test "does not enqueue a download job if the media item does not match the format rules" do
      profile = media_profile_fixture(%{shorts_behaviour: :exclude})
      source = source_fixture(%{media_profile_id: profile.id})

      stub(YtDlpRunnerMock, :run, fn _url, _opts, _ot ->
        output =
          Phoenix.json_library().encode!(%{
            id: "video2",
            title: "Video 2",
            webpage_url: "https://example.com/shorts/video2",
            was_live: true,
            description: "desc2",
            aspect_ratio: 1.67,
            duration: 345.67,
            upload_date: "20210101"
          })

        {:ok, output}
      end)

      assert {:ok, _media_item} = FastIndexingHelpers.index_and_enqueue_download_for_media_item(source, @media_url)
      refute_enqueued(worker: MediaDownloadWorker)
    end
  end
end
