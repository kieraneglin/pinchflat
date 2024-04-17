defmodule Pinchflat.FastIndexing.FastIndexingHelpersTest do
  use Pinchflat.DataCase

  import Mox
  import Pinchflat.MediaFixtures
  import Pinchflat.SourcesFixtures
  import Pinchflat.ProfilesFixtures

  alias Pinchflat.Tasks
  alias Pinchflat.Media.MediaItem
  alias Pinchflat.Downloading.MediaDownloadWorker
  alias Pinchflat.FastIndexing.FastIndexingHelpers

  setup :verify_on_exit!

  describe "kickoff_download_tasks_from_youtube_rss_feed/1" do
    setup do
      stub(YtDlpRunnerMock, :run, fn _url, _opts, _ot ->
        {:ok, media_attributes_return_fixture()}
      end)

      {:ok, [source: source_fixture()]}
    end

    test "enqueues a new worker for each new media_id in the source's RSS feed", %{source: source} do
      expect(HTTPClientMock, :get, fn _url -> {:ok, "<yt:videoId>test_1</yt:videoId>"} end)

      assert [media_item] = FastIndexingHelpers.kickoff_download_tasks_from_youtube_rss_feed(source)

      assert [worker] = all_enqueued(worker: MediaDownloadWorker)
      assert worker.args["id"] == media_item.id
    end

    test "does not enqueue a new worker for the source's media IDs we already know about", %{source: source} do
      expect(HTTPClientMock, :get, fn _url -> {:ok, "<yt:videoId>test_1</yt:videoId>"} end)
      media_item_fixture(source_id: source.id, media_id: "test_1")

      assert [] = FastIndexingHelpers.kickoff_download_tasks_from_youtube_rss_feed(source)

      refute_enqueued(worker: MediaDownloadWorker)
    end

    test "returns the found media items", %{source: source} do
      expect(HTTPClientMock, :get, fn _url -> {:ok, "<yt:videoId>test_1</yt:videoId>"} end)

      assert [%MediaItem{}] = FastIndexingHelpers.kickoff_download_tasks_from_youtube_rss_feed(source)
    end

    test "does not enqueue a download job if the source does not allow it" do
      expect(HTTPClientMock, :get, fn _url -> {:ok, "<yt:videoId>test_1</yt:videoId>"} end)
      source = source_fixture(%{download_media: false})

      assert [%MediaItem{}] = FastIndexingHelpers.kickoff_download_tasks_from_youtube_rss_feed(source)

      refute_enqueued(worker: MediaDownloadWorker)
    end

    test "creates a download task record", %{source: source} do
      expect(HTTPClientMock, :get, fn _url -> {:ok, "<yt:videoId>test_1</yt:videoId>"} end)

      assert [media_item] = FastIndexingHelpers.kickoff_download_tasks_from_youtube_rss_feed(source)

      assert [_] = Tasks.list_tasks_for(media_item, "MediaDownloadWorker")
    end

    test "does not enqueue a download job if the media item does not match the format rules" do
      expect(HTTPClientMock, :get, fn _url -> {:ok, "<yt:videoId>test_1</yt:videoId>"} end)

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

      assert [%MediaItem{}] = FastIndexingHelpers.kickoff_download_tasks_from_youtube_rss_feed(source)

      refute_enqueued(worker: MediaDownloadWorker)
    end

    test "does not blow up if a media item cannot be created", %{source: source} do
      expect(HTTPClientMock, :get, fn _url -> {:ok, "<yt:videoId>test_1</yt:videoId>"} end)

      stub(YtDlpRunnerMock, :run, fn _url, _opts, _ot ->
        {:ok, "{}"}
      end)

      assert [] = FastIndexingHelpers.kickoff_download_tasks_from_youtube_rss_feed(source)
    end

    test "does not blow up if a media item causes a yt-dlp error", %{source: source} do
      expect(HTTPClientMock, :get, fn _url -> {:ok, "<yt:videoId>test_1</yt:videoId>"} end)

      stub(YtDlpRunnerMock, :run, fn _url, _opts, _ot ->
        {:error, "message", 1}
      end)

      assert [] = FastIndexingHelpers.kickoff_download_tasks_from_youtube_rss_feed(source)
    end
  end
end
