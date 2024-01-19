defmodule Pinchflat.DownloaderBackends.YtDlp.CommandRunnerTest do
  use ExUnit.Case, async: true

  alias Pinchflat.DownloaderBackends.YtDlp.CommandRunner, as: Runner

  @cmd "echo"
  @video_url "https://www.youtube.com/watch?v=9bZkp7q19f0"

  describe "run/3" do
    test "it returns the output and status when the command succeeds" do
      assert {:ok, _output} = Runner.run(@video_url, [], base_command: @cmd)
    end

    test "it converts symbol k-v arg keys to kebab case" do
      assert {:ok, output} = Runner.run(@video_url, [buffer_size: 1024], base_command: @cmd)

      assert String.contains?(output, "--buffer-size 1024")
    end

    test "it keeps string k-v arg keys untouched" do
      assert {:ok, output} = Runner.run(@video_url, [{"--under_score", 1024}], base_command: @cmd)

      assert String.contains?(output, "--under_score 1024")
    end

    test "it converts symbol arg keys to kebab case" do
      assert {:ok, output} = Runner.run(@video_url, [:ignore_errors], base_command: @cmd)

      assert String.contains?(output, "--ignore-errors")
    end

    test "it keeps string arg keys untouched" do
      assert {:ok, output} = Runner.run(@video_url, ["-v"], base_command: @cmd)

      assert String.contains?(output, "-v")
      refute String.contains?(output, "--v")
    end

    test "it places arg keys (flags) at the beginning of the command" do
      assert {:ok, output} =
               Runner.run(@video_url, [{"--under_score", 1024}, :ignore_errors], base_command: @cmd)

      assert String.contains?(output, "--ignore-errors --under_score 1024")
    end

    test "it includes the video url as the last argument" do
      assert {:ok, output} = Runner.run(@video_url, [:ignore_errors], base_command: @cmd)

      assert String.contains?(output, "--ignore-errors #{@video_url}\n")
    end

    test "it returns the output and status when the command fails" do
      assert {:error, "", 1} = Runner.run(@video_url, [], base_command: "/bin/false")
    end
  end
end
