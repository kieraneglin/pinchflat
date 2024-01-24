defmodule Pinchflat.MediaClient.Backends.YtDlp.VideoTest do
  use ExUnit.Case, async: true
  import Mox

  alias Pinchflat.MediaClient.Backends.YtDlp.Video

  @video_url "https://www.youtube.com/watch?v=TiZPUDkDYbk"

  setup :verify_on_exit!

  describe "download/2" do
    test "it calls the backend runner with the expected arguments" do
      expect(YtDlpRunnerMock, :run, fn @video_url, opts ->
        assert opts == [:no_simulate, {:print, "%()j"}]

        {:ok, "{}"}
      end)

      assert {:ok, _} = Video.download(@video_url)
    end

    test "it passes along additional options" do
      expect(YtDlpRunnerMock, :run, fn _url, opts ->
        assert opts == [:no_simulate, {:print, "%()j"}, :custom_arg]

        {:ok, "{}"}
      end)

      assert {:ok, _} = Video.download(@video_url, [:custom_arg])
    end

    test "it parses the output as JSON" do
      expect(YtDlpRunnerMock, :run, fn _url, _opts -> {:ok, "{\"title\": \"Test\"}"} end)

      assert {:ok, %{"title" => "Test"}} = Video.download(@video_url)
    end

    test "it returns an error if the output is not JSON" do
      expect(YtDlpRunnerMock, :run, fn _url, _opts -> {:ok, "Not JSON"} end)

      assert {:error, %Jason.DecodeError{}} = Video.download(@video_url)
    end

    test "it directly passes along any errors" do
      expect(YtDlpRunnerMock, :run, fn _url, _opts -> {:error, "Big issue", 1} end)

      assert {:error, "Big issue", 1} = Video.download(@video_url)
    end
  end
end
