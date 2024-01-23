defmodule Pinchflat.Downloader.ChannelDetailsTest do
  use ExUnit.Case, async: true
  import Mox

  alias Pinchflat.Downloader.ChannelDetails

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
      expect(CommandRunnerMock, :run, fn @channel_url, opts ->
        assert opts == [{:print, "%(.{channel,channel_id})j"}, {:playlist_end, 1}]

        {:ok, "{\"channel\": \"TheUselessTrials\", \"channel_id\": \"UCQH2\"}"}
      end)

      assert {:ok, _} = ChannelDetails.get_channel_details(@channel_url)
    end

    test "it returns a struct composed of the returned data" do
      expect(CommandRunnerMock, :run, fn _url, _opts ->
        {:ok, "{\"channel\": \"TheUselessTrials\", \"channel_id\": \"UCQH2\"}"}
      end)

      assert {:ok, res} = ChannelDetails.get_channel_details(@channel_url)
      assert %ChannelDetails{id: "UCQH2", name: "TheUselessTrials"} = res
    end
  end
end
