defmodule Pinchflat.MediaClient.SourceDetailsTest do
  use Pinchflat.DataCase
  import Mox
  import Pinchflat.ProfilesFixtures
  import Pinchflat.MediaSourceFixtures

  alias Pinchflat.MediaClient.SourceDetails

  @channel_url "https://www.youtube.com/c/TheUselessTrials"

  setup :verify_on_exit!

  describe "get_source_details/2" do
    test "it passes the expected arguments to the backend" do
      expect(YtDlpRunnerMock, :run, fn @channel_url, opts, ot ->
        assert opts == [:simulate, :skip_download, playlist_end: 1]
        assert ot == "%(.{channel,channel_id,playlist_id,playlist_title})j"

        {:ok, "{}"}
      end)

      assert {:ok, _} = SourceDetails.get_source_details(@channel_url)
    end

    test "it returns a struct composed of the returned data" do
      expect(YtDlpRunnerMock, :run, fn _url, _opts, _ot ->
        Phoenix.json_library().encode(%{
          channel: "TheUselessTrials",
          channel_id: "UCQH2",
          playlist_id: "PLQH2",
          playlist_title: "TheUselessTrials - Videos"
        })
      end)

      assert {:ok, res} = SourceDetails.get_source_details(@channel_url)

      assert %{
               channel_id: "UCQH2",
               channel_name: "TheUselessTrials",
               playlist_id: "PLQH2",
               playlist_name: "TheUselessTrials - Videos"
             } = res
    end
  end

  describe "get_video_ids/2 when passed a string" do
    test "it passes the expected arguments to the backend" do
      expect(YtDlpRunnerMock, :run, fn @channel_url, opts, ot ->
        assert opts == [:simulate, :skip_download]
        assert ot == "%(id)s"

        {:ok, ""}
      end)

      assert {:ok, _} = SourceDetails.get_video_ids(@channel_url)
    end

    test "it returns a list of strings" do
      expect(YtDlpRunnerMock, :run, fn _url, _opts, _ot ->
        {:ok, "video1\nvideo2\nvideo3"}
      end)

      assert {:ok, ["video1", "video2", "video3"]} = SourceDetails.get_video_ids(@channel_url)
    end
  end

  describe "get_video_ids/2 when passed a Source record" do
    test "it calls the backend with the source's collection ID" do
      source = source_fixture()

      expect(YtDlpRunnerMock, :run, fn url, _opts, _ot ->
        assert source.collection_id == url
        {:ok, "video1\nvideo2\nvideo3"}
      end)

      assert {:ok, _} = SourceDetails.get_video_ids(source)
    end

    test "it builds options based on the source's media profile" do
      expect(YtDlpRunnerMock, :run, fn _url, opts, _ot ->
        assert opts == [{:match_filter, "!was_live"}, :simulate, :skip_download]
        {:ok, ""}
      end)

      media_profile =
        media_profile_fixture(
          shorts_behaviour: :include,
          livestream_behaviour: :exclude
        )

      source = source_fixture(media_profile_id: media_profile.id)
      assert {:ok, _} = SourceDetails.get_video_ids(source)
    end
  end
end
