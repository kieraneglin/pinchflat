defmodule Pinchflat.Downloader.Backends.YtDlp.VideoTest do
  use ExUnit.Case, async: true
  import Mox

  alias Pinchflat.Downloader.Backends.YtDlp.Video

  @video_url "https://www.youtube.com/watch?v=TiZPUDkDYbk"

  setup :verify_on_exit!

  describe "download/2" do
    test "it calls the backend runner with the expected arguments" do
      expect(CommandRunnerMock, :run, fn @video_url, opts ->
        assert opts == [:no_simulate, :dump_json]

        {:ok, "{}"}
      end)

      assert {:ok, _} = Video.download(@video_url)
    end

    test "it passes along additional options" do
      expect(CommandRunnerMock, :run, fn _url, opts ->
        assert opts == [:no_simulate, :dump_json, :custom_arg]

        {:ok, "{}"}
      end)

      assert {:ok, _} = Video.download(@video_url, [:custom_arg])
    end

    test "it parses the output as JSON" do
      expect(CommandRunnerMock, :run, fn _url, _opts -> {:ok, "{\"title\": \"Test\"}"} end)

      assert {:ok, %{"title" => "Test"}} = Video.download(@video_url)
    end

    test "it directly passes along any errors" do
      expect(CommandRunnerMock, :run, fn _url, _opts -> {:error, "Big issue", 1} end)

      assert {:error, "Big issue", 1} = Video.download(@video_url)
    end
  end
end
