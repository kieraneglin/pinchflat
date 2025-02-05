defmodule Pinchflat.FastIndexing.YoutubeApiTest do
  use Pinchflat.DataCase

  import Pinchflat.SourcesFixtures

  alias Pinchflat.Settings
  alias Pinchflat.FastIndexing.YoutubeApi

  describe "enabled?/0" do
    test "returns true if the user has set YouTube API keys" do
      Settings.set(youtube_api_key: "key1, key2")
      assert YoutubeApi.enabled?()
    end

    test "returns true with a single API key" do
      Settings.set(youtube_api_key: "test_key")

      assert YoutubeApi.enabled?()
    end

    test "returns false if the user has not set any API keys" do
      Settings.set(youtube_api_key: nil)
      refute YoutubeApi.enabled?()
    end

    test "returns false if only empty or whitespace keys are provided" do
      Settings.set(youtube_api_key: "  ,  ,")
      refute YoutubeApi.enabled?()
    end
  end

  describe "get_recent_media_ids/1" do
    setup do
      case :global.whereis_name(YoutubeApi.KeyIndex) do
        :undefined -> :ok
        pid -> Agent.stop(pid)
      end

      source = source_fixture()
      Settings.set(youtube_api_key: "key1, key2")

      {:ok, source: source}
    end

    test "rotates through API keys", %{source: source} do
      expect(HTTPClientMock, :get, fn url, _headers ->
        assert url =~ "key=key1"
        {:ok, "{}"}
      end)

      expect(HTTPClientMock, :get, fn url, _headers ->
        assert url =~ "key=key2"
        {:ok, "{}"}
      end)

      expect(HTTPClientMock, :get, fn url, _headers ->
        assert url =~ "key=key1"
        {:ok, "{}"}
      end)

      # three calls to verify rotation
      YoutubeApi.get_recent_media_ids(source)
      YoutubeApi.get_recent_media_ids(source)
      YoutubeApi.get_recent_media_ids(source)
    end

    test "calls the expected URL", %{source: source} do
      expect(HTTPClientMock, :get, fn url, headers ->
        api_base = "https://youtube.googleapis.com/youtube/v3/playlistItems"
        request_url = "#{api_base}?part=contentDetails&maxResults=50&playlistId=#{source.collection_id}&key=key1"

        assert url == request_url
        assert headers == [accept: "application/json"]

        {:ok, "{}"}
      end)

      assert {:ok, _} = YoutubeApi.get_recent_media_ids(source)
    end

    test "replaces channel IDs with playlist IDs if needed" do
      source = source_fixture(collection_id: "UC_ABC123")

      expect(HTTPClientMock, :get, fn url, _headers ->
        assert url =~ "playlistId=UU_ABC123&"

        {:ok, "{}"}
      end)

      assert {:ok, _} = YoutubeApi.get_recent_media_ids(source)
    end

    test "returns an empty list if no media is returned", %{source: source} do
      expect(HTTPClientMock, :get, fn _url, _headers -> {:ok, "{}"} end)

      assert {:ok, []} = YoutubeApi.get_recent_media_ids(source)
    end

    test "returns media IDs if present", %{source: source} do
      expect(HTTPClientMock, :get, fn _url, _headers ->
        {:ok,
         """
           {
             "items": [
               {"contentDetails": {"videoId": "test_1"}},
               {"contentDetails": {"videoId": "test_2"}}
             ]
           }
         """}
      end)

      assert {:ok, ["test_1", "test_2"]} = YoutubeApi.get_recent_media_ids(source)
    end

    test "returns an error if the HTTP request fails", %{source: source} do
      expect(HTTPClientMock, :get, fn _url, _headers -> {:error, "error"} end)

      assert {:error, "error"} = YoutubeApi.get_recent_media_ids(source)
    end
  end
end
