defmodule Pinchflat.YtDlp.UpdateWorkerTest do
  use Pinchflat.DataCase

  alias Pinchflat.Settings
  alias Pinchflat.YtDlp.UpdateWorker

  describe "perform/1" do
    test "calls the yt-dlp runner to update yt-dlp" do
      expect(YtDlpRunnerMock, :update, fn -> {:ok, ""} end)
      expect(YtDlpRunnerMock, :version, fn -> {:ok, ""} end)

      perform_job(UpdateWorker, %{})
    end

    test "saves the new version to the database" do
      expect(YtDlpRunnerMock, :update, fn -> {:ok, ""} end)
      expect(YtDlpRunnerMock, :version, fn -> {:ok, "1.2.3"} end)

      perform_job(UpdateWorker, %{})

      assert {:ok, "1.2.3"} = Settings.get(:yt_dlp_version)
    end
  end
end
