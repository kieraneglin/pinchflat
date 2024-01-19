defmodule Pinchflat.DownloaderBackends.YtDlp.CommandRunnerTest do
  use ExUnit.Case, async: true

  alias Pinchflat.DownloaderBackends.YtDlp.CommandRunner, as: Runner

  @cmd Path.join([File.cwd!(), "/test/support/scripts/mock-yt-dlp-repeater.sh"])
  @video_url "https://www.youtube.com/watch?v=9bZkp7q19f0"
  @original_executables Application.compile_env(:pinchflat, :backend_executables)

  setup do
    Application.put_env(:pinchflat, :backend_executables, %{@original_executables | yt_dlp: @cmd})

    on_exit(fn ->
      Application.put_env(:pinchflat, :backend_executables, @original_executables)
    end)
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
      Application.put_env(:pinchflat, :backend_executables, %{
        @original_executables
        | yt_dlp: "/bin/false"
      })

      assert {:error, "", 1} = Runner.run(@video_url, [])
    end
  end

  describe "run_json/2" do
    test "it returns decoded JSON when the command succeeds" do
      assert {:ok, output} = Runner.run_json(@video_url, [])

      assert is_map(output)
    end

    test "it adds the --dump-json flag automatically" do
      assert {:ok, %{"args" => output}} = Runner.run_json(@video_url, [])

      assert String.contains?(output, "--dump-json")
    end

    test "it returns errors when the command fails" do
      Application.put_env(:pinchflat, :backend_executables, %{
        @original_executables
        | yt_dlp: "/bin/false"
      })

      assert {:error, "", 1} = Runner.run_json(@video_url, [])
    end
  end
end
