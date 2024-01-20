defmodule Pinchflat.DownloaderBackends.YtDlp.VideoCollectionTest do
  use ExUnit.Case, async: true
  import Mox

  alias Pinchflat.DownloaderBackends.YtDlp.VideoCollection, as: VideoCollection

  @channel_url "https://www.youtube.com/@TheUselessTrials"

  setup :verify_on_exit!

  describe "get_video_ids/2" do
    test "returns a list of video ids with no blank elements" do
      expect(CommandRunnerMock, :run, fn _url, _opts -> {:ok, "id1\nid2\n\nid3\n"} end)

      assert {:ok, ["id1", "id2", "id3"]} = VideoCollection.get_video_ids(@channel_url)
    end

    test "it passes the expected default args" do
      expect(CommandRunnerMock, :run, fn _url, opts ->
        assert opts == [:simulate, :skip_download, :get_id]

        {:ok, ""}
      end)

      assert {:ok, _} = VideoCollection.get_video_ids(@channel_url)
    end

    test "it passes the expected custom args" do
      expect(CommandRunnerMock, :run, fn _url, opts ->
        assert opts == [:custom_arg, :simulate, :skip_download, :get_id]

        {:ok, ""}
      end)

      assert {:ok, _} = VideoCollection.get_video_ids(@channel_url, [:custom_arg])
    end

    test "returns the error straight through when the command fails" do
      expect(CommandRunnerMock, :run, fn _url, _opts -> {:error, "Big issue", 1} end)

      assert {:error, "Big issue", 1} = VideoCollection.get_video_ids(@channel_url)
    end
  end
end
