defmodule Pinchflat.Downloader.VideoDownloaderTest do
  use ExUnit.Case, async: true
  import Mox

  alias Pinchflat.Profiles.MediaProfile
  alias Pinchflat.Downloader.VideoDownloader

  @video_url "https://www.youtube.com/watch?v=TiZPUDkDYbk"
  @media_profile %MediaProfile{
    output_path_template: "videos/{{ title }}.%(ext)s"
  }

  setup :verify_on_exit!

  describe "download_for_media_profile/3" do
    test "it calls the backend runner with the arguments built from the media profile" do
      expect(CommandRunnerMock, :run, fn @video_url, opts ->
        assert :no_simulate in opts
        assert :dump_json in opts
        assert {:output, "/tmp/yt-dlp/videos/%(title)S.%(ext)s"} in opts

        {:ok, "{}"}
      end)

      assert {:ok, _} = VideoDownloader.download_for_media_profile(@video_url, @media_profile)
    end

    test "it returns the parsed JSON output" do
      expect(CommandRunnerMock, :run, fn _url, _opts -> {:ok, "{\"title\": \"Test\"}"} end)

      assert {:ok, %{"title" => "Test"}} =
               VideoDownloader.download_for_media_profile(@video_url, @media_profile)
    end
  end
end
