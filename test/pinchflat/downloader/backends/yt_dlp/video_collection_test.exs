defmodule Pinchflat.Downloader.Backends.YtDlp.VideoCollectionTest do
  use ExUnit.Case, async: true
  import Mox

  alias Pinchflat.Downloader.Backends.YtDlp.VideoCollection

  @channel_url "https://www.youtube.com/@TheUselessTrials"

  defmodule VideoCollectionUser do
    use VideoCollection
  end

  setup :verify_on_exit!

  describe "get_video_ids/2" do
    test "returns a list of video ids with no blank elements" do
      expect(YtDlpRunnerMock, :run, fn _url, _opts -> {:ok, "id1\nid2\n\nid3\n"} end)

      assert {:ok, ["id1", "id2", "id3"]} = VideoCollectionUser.get_video_ids(@channel_url)
    end

    test "it passes the expected default args" do
      expect(YtDlpRunnerMock, :run, fn _url, opts ->
        assert opts == [:simulate, :skip_download, {:print, :id}]

        {:ok, ""}
      end)

      assert {:ok, _} = VideoCollectionUser.get_video_ids(@channel_url)
    end

    test "it passes the expected custom args" do
      expect(YtDlpRunnerMock, :run, fn _url, opts ->
        assert opts == [:custom_arg, :simulate, :skip_download, {:print, :id}]

        {:ok, ""}
      end)

      assert {:ok, _} = VideoCollectionUser.get_video_ids(@channel_url, [:custom_arg])
    end

    test "returns the error straight through when the command fails" do
      expect(YtDlpRunnerMock, :run, fn _url, _opts -> {:error, "Big issue", 1} end)

      assert {:error, "Big issue", 1} = VideoCollectionUser.get_video_ids(@channel_url)
    end
  end
end
