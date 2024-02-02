defmodule Pinchflat.MediaClient.ChannelDetailsTest do
  use ExUnit.Case, async: true
  import Mox

  alias Pinchflat.MediaClient.ChannelDetails

  @channel_url "https://www.youtube.com/c/TheUselessTrials"

  setup :verify_on_exit!

  describe "new/2" do
    test "it returns a struct with the given values" do
      assert %ChannelDetails{id: "UCQH2", name: "TheUselessTrials"} =
               ChannelDetails.new("UCQH2", "TheUselessTrials")
    end
  end

  describe "get_channel_details/2" do
    test "it passes the expected arguments to the backend" do
      expect(YtDlpRunnerMock, :run, fn @channel_url, opts, ot ->
        assert opts == [:skip_download, playlist_end: 1]
        assert ot == "%(.{channel,channel_id})j"

        {:ok, "{\"channel\": \"TheUselessTrials\", \"channel_id\": \"UCQH2\"}"}
      end)

      assert {:ok, _} = ChannelDetails.get_channel_details(@channel_url)
    end

    test "it returns a struct composed of the returned data" do
      expect(YtDlpRunnerMock, :run, fn _url, _opts, _ot ->
        {:ok, "{\"channel\": \"TheUselessTrials\", \"channel_id\": \"UCQH2\"}"}
      end)

      assert {:ok, res} = ChannelDetails.get_channel_details(@channel_url)
      assert %ChannelDetails{id: "UCQH2", name: "TheUselessTrials"} = res
    end
  end

  describe "get_video_ids/2" do
    test "it passes the expected arguments to the backend" do
      expect(YtDlpRunnerMock, :run, fn @channel_url, opts, ot ->
        assert opts == [:simulate, :skip_download]
        assert ot == "%(id)s"

        {:ok, ""}
      end)

      assert {:ok, _} = ChannelDetails.get_video_ids(@channel_url)
    end

    test "it returns a list of strings" do
      expect(YtDlpRunnerMock, :run, fn _url, _opts, _ot ->
        {:ok, "video1\nvideo2\nvideo3"}
      end)

      assert {:ok, ["video1", "video2", "video3"]} = ChannelDetails.get_video_ids(@channel_url)
    end
  end
end
