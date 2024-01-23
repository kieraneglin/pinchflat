defmodule Pinchflat.MediaClient.Backends.YtDlp.CommandRunnerTest do
  use ExUnit.Case, async: true

  alias Pinchflat.MediaClient.Backends.YtDlp.CommandRunner, as: Runner

  @original_executable Application.compile_env(:pinchflat, :yt_dlp_executable)
  @video_url "https://www.youtube.com/watch?v=-LHXuyzpex0"

  setup do
    on_exit(&reset_executable/0)
  end

  describe "run/2" do
    test "it returns the output and status when the command succeeds" do
      assert {:ok, _output} = Runner.run(@video_url, [])
    end

    test "it converts symbol k-v arg keys to kebab case" do
      assert {:ok, output} = Runner.run(@video_url, buffer_size: 1024)

      assert String.contains?(output, "--buffer-size 1024")
    end

    test "it keeps string k-v arg keys untouched" do
      assert {:ok, output} = Runner.run(@video_url, [{"--under_score", 1024}])

      assert String.contains?(output, "--under_score 1024")
    end

    test "it converts symbol arg keys to kebab case" do
      assert {:ok, output} = Runner.run(@video_url, [:ignore_errors])

      assert String.contains?(output, "--ignore-errors")
    end

    test "it keeps string arg keys untouched" do
      assert {:ok, output} = Runner.run(@video_url, ["-v"])

      assert String.contains?(output, "-v")
      refute String.contains?(output, "--v")
    end

    test "it places arg keys (flags) at the beginning of the command" do
      assert {:ok, output} =
               Runner.run(@video_url, [{"--under_score", 1024}, :ignore_errors])

      assert String.contains?(output, "--ignore-errors --under_score 1024")
    end

    test "it includes the video url as the last argument" do
      assert {:ok, output} = Runner.run(@video_url, [:ignore_errors])

      assert String.contains?(output, "--ignore-errors #{@video_url}\n")
    end

    test "it returns the output and status when the command fails" do
      wrap_executable("/bin/false", fn ->
        assert {:error, "", 1} = Runner.run(@video_url, [])
      end)
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
