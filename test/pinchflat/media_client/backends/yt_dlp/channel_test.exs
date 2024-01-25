defmodule Pinchflat.MediaClient.Backends.YtDlp.ChannelTest do
  use ExUnit.Case, async: true
  import Mox

  alias Pinchflat.MediaClient.ChannelDetails
  alias Pinchflat.MediaClient.Backends.YtDlp.Channel

  @channel_url "https://www.youtube.com/c/TheUselessTrials"

  setup :verify_on_exit!

  describe "get_channel_details/1" do
    test "it returns a %ChannelDetails{} with data on success" do
      expect(YtDlpRunnerMock, :run, fn _url, _opts ->
        {:ok, "{\"channel\": \"TheUselessTrials\", \"channel_id\": \"UCQH2\"}"}
      end)

      assert {:ok, res} = Channel.get_channel_details(@channel_url)
      assert %ChannelDetails{id: "UCQH2", name: "TheUselessTrials"} = res
    end

    test "it passes the expected args to the backend runner" do
      expect(YtDlpRunnerMock, :run, fn @channel_url, opts ->
        assert opts == [{:print, "%(.{channel,channel_id})j"}, {:playlist_end, 1}]

        {:ok, "{}"}
      end)

      assert {:ok, _} = Channel.get_channel_details(@channel_url)
    end

    test "it returns an error if the runner returns an error" do
      expect(YtDlpRunnerMock, :run, fn _url, _opts -> {:error, "Big issue", 1} end)

      assert {:error, "Big issue", 1} = Channel.get_channel_details(@channel_url)
    end

    test "it returns an error if the output is not JSON" do
      expect(YtDlpRunnerMock, :run, fn _url, _opts -> {:ok, "Not JSON"} end)

      assert {:error, %Jason.DecodeError{}} = Channel.get_channel_details(@channel_url)
    end
  end
end
