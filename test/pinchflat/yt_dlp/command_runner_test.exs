defmodule Pinchflat.YtDlp.CommandRunnerTest do
  use ExUnit.Case, async: true

  alias Pinchflat.Filesystem.FilesystemHelpers

  alias Pinchflat.YtDlp.CommandRunner, as: Runner

  @original_executable Application.compile_env(:pinchflat, :yt_dlp_executable)
  @media_url "https://www.youtube.com/watch?v=-LHXuyzpex0"

  setup do
    on_exit(&reset_executable/0)
  end

  describe "run/4" do
    test "it returns the output and status when the command succeeds" do
      assert {:ok, _output} = Runner.run(@media_url, [], "")
    end

    test "it converts symbol k-v arg keys to kebab case" do
      assert {:ok, output} = Runner.run(@media_url, [buffer_size: 1024], "")

      assert String.contains?(output, "--buffer-size 1024")
    end

    test "it keeps string k-v arg keys untouched" do
      assert {:ok, output} = Runner.run(@media_url, [{"--under_score", 1024}], "")

      assert String.contains?(output, "--under_score 1024")
    end

    test "it converts symbol arg keys to kebab case" do
      assert {:ok, output} = Runner.run(@media_url, [:ignore_errors], "")

      assert String.contains?(output, "--ignore-errors")
    end

    test "it keeps string arg keys untouched" do
      assert {:ok, output} = Runner.run(@media_url, ["-v"], "")

      assert String.contains?(output, "-v")
      refute String.contains?(output, "--v")
    end

    test "it includes the media url as the first argument" do
      assert {:ok, output} = Runner.run(@media_url, [:ignore_errors], "")

      assert String.contains?(output, "#{@media_url} --ignore-errors")
    end

    test "it automatically includes the --print-to-file flag" do
      assert {:ok, output} = Runner.run(@media_url, [], "%(id)s")

      assert String.contains?(output, "--print-to-file %(id)s /tmp/")
    end

    test "it returns the output and status when the command fails" do
      wrap_executable("/bin/false", fn ->
        assert {:error, "", 1} = Runner.run(@media_url, [], "")
      end)
    end

    test "optionally lets you specify an output_filepath" do
      assert {:ok, output} = Runner.run(@media_url, [], "%(id)s", output_filepath: "/tmp/yt-dlp-output.json")

      assert String.contains?(output, "--print-to-file %(id)s /tmp/yt-dlp-output.json")
    end
  end

  describe "run/4 when testing cookie options" do
    setup do
      base_dir = Application.get_env(:pinchflat, :extras_directory)
      cookie_file = Path.join(base_dir, "cookies.txt")

      {:ok, cookie_file: cookie_file}
    end

    test "includes cookie options when cookies.txt exists", %{cookie_file: cookie_file} do
      FilesystemHelpers.write_p!(cookie_file, "cookie data")

      assert {:ok, output} = Runner.run(@media_url, [], "")

      assert String.contains?(output, "--cookies #{cookie_file}")
    end

    test "doesn't include cookie options when cookies.txt blank", %{cookie_file: cookie_file} do
      FilesystemHelpers.write_p!(cookie_file, " \n \n ")

      assert {:ok, output} = Runner.run(@media_url, [], "")

      refute String.contains?(output, "--cookies")
      refute String.contains?(output, cookie_file)
    end

    test "doesn't include cookie options when cookies.txt doesn't exist", %{cookie_file: cookie_file} do
      File.rm(cookie_file)

      assert {:ok, output} = Runner.run(@media_url, [], "")

      refute String.contains?(output, "--cookies")
      refute String.contains?(output, cookie_file)
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
