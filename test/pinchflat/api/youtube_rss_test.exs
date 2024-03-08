defmodule Pinchflat.Api.YoutubeRssTest do
  use Pinchflat.DataCase
  import Mox
  import Pinchflat.SourcesFixtures

  alias Pinchflat.Api.YoutubeRss

  setup :verify_on_exit!

  setup do
    source = source_fixture()

    {:ok, source: source}
  end

  describe "get_recent_media_ids_from_rss/1" do
    test "calls the expected URL for channel sources" do
      source = source_fixture(collection_type: :channel, collection_id: "channel_id")

      expect(HTTPClientMock, :get, fn url ->
        assert url =~ "https://www.youtube.com/feeds/videos.xml?channel_id=#{source.collection_id}"

        {:ok, ""}
      end)

      assert {:ok, _} = YoutubeRss.get_recent_media_ids_from_rss(source)
    end

    test "calls the expected URL for playlist sources" do
      source = source_fixture(collection_type: :playlist, collection_id: "playlist_id")

      expect(HTTPClientMock, :get, fn url ->
        assert url =~ "https://www.youtube.com/feeds/videos.xml?playlist_id=#{source.collection_id}"

        {:ok, ""}
      end)

      assert {:ok, _} = YoutubeRss.get_recent_media_ids_from_rss(source)
    end

    test "returns an error if the HTTP request fails", %{source: source} do
      expect(HTTPClientMock, :get, fn _url -> {:error, ""} end)

      assert {:error, "Failed to fetch RSS feed"} = YoutubeRss.get_recent_media_ids_from_rss(source)
    end

    test "returns the media IDs from the RSS feed", %{source: source} do
      expect(HTTPClientMock, :get, fn _url ->
        {:ok, "<yt:videoId>test_1</yt:videoId><yt:videoId>test_2</yt:videoId>"}
      end)

      assert {:ok, ["test_1", "test_2"]} = YoutubeRss.get_recent_media_ids_from_rss(source)
    end

    test "strips whitespace from media IDs", %{source: source} do
      expect(HTTPClientMock, :get, fn _url ->
        {:ok, "<yt:videoId> test_1 </yt:videoId><yt:videoId> test_2 </yt:videoId>"}
      end)

      assert {:ok, ["test_1", "test_2"]} = YoutubeRss.get_recent_media_ids_from_rss(source)
    end

    test "removes empty media IDs", %{source: source} do
      expect(HTTPClientMock, :get, fn _url ->
        {:ok, "<yt:videoId>test_1</yt:videoId><yt:videoId></yt:videoId>"}
      end)

      assert {:ok, ["test_1"]} = YoutubeRss.get_recent_media_ids_from_rss(source)
    end
  end
end
