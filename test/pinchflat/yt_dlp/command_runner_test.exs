defmodule Pinchflat.YtDlp.CommandRunnerTest do
  use Pinchflat.DataCase

  alias Pinchflat.Settings
  alias Pinchflat.Utils.FilesystemUtils

  alias Pinchflat.YtDlp.CommandRunner, as: Runner

  @original_executable Application.compile_env(:pinchflat, :yt_dlp_executable)
  @media_url "https://www.youtube.com/watch?v=-LHXuyzpex0"

  setup do
    on_exit(&reset_executable/0)
  end

  describe "run/4" do
    test "returns the output and status when the command succeeds" do
      assert {:ok, _output} = Runner.run(@media_url, :foo, [], "")
    end

    test "considers a 101 exit code as being successful" do
      wrap_executable("/app/test/support/scripts/yt-dlp-mocks/101_exit_code.sh", fn ->
        assert {:ok, _output} = Runner.run(@media_url, :foo, [], "")
      end)
    end

    test "includes the media url as the first argument" do
      assert {:ok, output} = Runner.run(@media_url, :foo, [:ignore_errors], "")

      assert String.contains?(output, "#{@media_url} --ignore-errors")
    end

    test "automatically includes the --print-to-file flag" do
      assert {:ok, output} = Runner.run(@media_url, :foo, [], "%(id)s")

      assert String.contains?(output, "--print-to-file %(id)s /tmp/")
    end

    test "returns the output and status when the command fails" do
      wrap_executable("/bin/false", fn ->
        assert {:error, "", 1} = Runner.run(@media_url, :foo, [], "")
      end)
    end

    test "optionally lets you specify an output_filepath" do
      assert {:ok, output} = Runner.run(@media_url, :foo, [], "%(id)s", output_filepath: "/tmp/yt-dlp-output.json")

      assert String.contains?(output, "--print-to-file %(id)s /tmp/yt-dlp-output.json")
    end
  end

  describe "run/4 when testing external file options" do
    setup do
      base_dir = Application.get_env(:pinchflat, :extras_directory)
      cookie_file = Path.join(base_dir, "cookies.txt")
      yt_dlp_file = Path.join([base_dir, "yt-dlp-configs", "main.txt"])

      {:ok, cookie_file: cookie_file, yt_dlp_file: yt_dlp_file}
    end

    test "includes cookie options when cookies.txt exists and enabled", %{cookie_file: cookie_file} do
      FilesystemUtils.write_p!(cookie_file, "cookie data")

      assert {:ok, output} = Runner.run(@media_url, :foo, [], "", use_cookies: true)

      assert String.contains?(output, "--cookies #{cookie_file}")
    end

    test "doesn't include cookie options when cookies.txt exists but disabled", %{cookie_file: cookie_file} do
      FilesystemUtils.write_p!(cookie_file, "cookie data")

      assert {:ok, output} = Runner.run(@media_url, :foo, [], "", use_cookies: false)

      refute String.contains?(output, "--cookies #{cookie_file}")
    end

    test "doesn't include cookie options when cookies.txt blank", %{cookie_file: cookie_file} do
      FilesystemUtils.write_p!(cookie_file, " \n \n ")

      assert {:ok, output} = Runner.run(@media_url, :foo, [], "", use_cookies: true)

      refute String.contains?(output, "--cookies")
      refute String.contains?(output, cookie_file)
    end

    test "doesn't include cookie options when cookies.txt doesn't exist", %{cookie_file: cookie_file} do
      File.rm(cookie_file)

      assert {:ok, output} = Runner.run(@media_url, :foo, [], "")

      refute String.contains?(output, "--cookies")
      refute String.contains?(output, cookie_file)

      # Cleanup
      FilesystemUtils.write_p!(cookie_file, "")
    end
  end

  describe "run/4 when testing rate limit options" do
    test "includes sleep interval options by default" do
      Settings.set(extractor_sleep_interval_seconds: 5)

      assert {:ok, output} = Runner.run(@media_url, :foo, [], "")

      assert String.contains?(output, "--sleep-interval")
      assert String.contains?(output, "--sleep-requests")
      assert String.contains?(output, "--sleep-subtitles")
    end

    test "doesn't include sleep interval options when skip_sleep_interval is true" do
      assert {:ok, output} = Runner.run(@media_url, :foo, [], "", skip_sleep_interval: true)

      refute String.contains?(output, "--sleep-interval")
      refute String.contains?(output, "--sleep-requests")
      refute String.contains?(output, "--sleep-subtitles")
    end

    test "doesn't include sleep interval options when extractor_sleep_interval_seconds is 0" do
      Settings.set(extractor_sleep_interval_seconds: 0)

      assert {:ok, output} = Runner.run(@media_url, :foo, [], "")

      refute String.contains?(output, "--sleep-interval")
      refute String.contains?(output, "--sleep-requests")
      refute String.contains?(output, "--sleep-subtitles")
    end

    test "includes limit_rate option when specified" do
      Settings.set(download_throughput_limit: "100K")

      assert {:ok, output} = Runner.run(@media_url, :foo, [], "")

      assert String.contains?(output, "--limit-rate 100K")
    end

    test "doesn't include limit_rate option when download_throughput_limit is nil" do
      Settings.set(download_throughput_limit: nil)

      assert {:ok, output} = Runner.run(@media_url, :foo, [], "")

      refute String.contains?(output, "--limit-rate")
    end
  end

  describe "run/4 when testing global options" do
    test "creates windows-safe filenames" do
      assert {:ok, output} = Runner.run(@media_url, :foo, [], "")

      assert String.contains?(output, "--windows-filenames")
    end

    test "runs quietly" do
      assert {:ok, output} = Runner.run(@media_url, :foo, [], "")

      assert String.contains?(output, "--quiet")
    end

    test "sets the cache directory" do
      assert {:ok, output} = Runner.run(@media_url, :foo, [], "")

      assert String.contains?(output, "--cache-dir /tmp/test/tmpfiles/yt-dlp-cache")
    end
  end

  describe "version/0" do
    test "adds the version arg" do
      assert {:ok, output} = Runner.version()

      assert String.contains?(output, "--version")
    end
  end

  describe "update/0" do
    test "adds the update arg" do
      assert {:ok, output} = Runner.update()

      assert String.contains?(output, "--update")
    end
  end

  defp wrap_executable(new_executable, fun) do
    Application.put_env(:pinchflat, :yt_dlp_executable, new_executable)
    fun.()
    reset_executable()
  end

  def reset_executable do
    Application.put_env(:pinchflat, :yt_dlp_executable, @original_executable)
  end
end
