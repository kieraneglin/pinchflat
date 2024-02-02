defmodule Pinchflat.MediaClient.Backends.YtDlp.ChannelTest do
  use ExUnit.Case, async: true
  import Mox

  alias Pinchflat.MediaClient.SourceDetails
  alias Pinchflat.MediaClient.Backends.YtDlp.Channel

  @channel_url "https://www.youtube.com/c/TheUselessTrials"

  setup :verify_on_exit!

  describe "get_source_details/1" do
    test "it returns a %SourceDetails{} with data on success" do
      expect(YtDlpRunnerMock, :run, fn _url, _opts, _ot ->
        {:ok, "{\"channel\": \"TheUselessTrials\", \"channel_id\": \"UCQH2\"}"}
      end)

      assert {:ok, res} = Channel.get_source_details(@channel_url)
      assert %SourceDetails{id: "UCQH2", name: "TheUselessTrials"} = res
    end

    test "it passes the expected args to the backend runner" do
      expect(YtDlpRunnerMock, :run, fn @channel_url, opts, ot ->
        assert opts == [:skip_download, playlist_end: 1]
        assert ot == "%(.{channel,channel_id})j"

        {:ok, "{}"}
      end)

      assert {:ok, _} = Channel.get_source_details(@channel_url)
    end

    test "it returns an error if the runner returns an error" do
      expect(YtDlpRunnerMock, :run, fn _url, _opts, _ot -> {:error, "Big issue", 1} end)

      assert {:error, "Big issue", 1} = Channel.get_source_details(@channel_url)
    end

    test "it returns an error if the output is not JSON" do
      expect(YtDlpRunnerMock, :run, fn _url, _opts, _ot -> {:ok, "Not JSON"} end)

      assert {:error, %Jason.DecodeError{}} = Channel.get_source_details(@channel_url)
    end
  end
end
