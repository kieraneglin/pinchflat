defmodule Pinchflat.Boot.PostBootStartupTasksTest do
  use Pinchflat.DataCase

  # import Pinchflat.JobFixtures

  # alias Pinchflat.Settings
  alias Pinchflat.YtDlp.UpdateWorker
  alias Pinchflat.Boot.PostBootStartupTasks

  setup do
    stub(YtDlpRunnerMock, :update, fn -> {:ok, "1"} end)
    stub(YtDlpRunnerMock, :version, fn -> {:ok, "1"} end)

    :ok
  end

  describe "update_yt_dlp" do
    test "enqueues an update job" do
      assert [] = all_enqueued(worker: UpdateWorker)

      PostBootStartupTasks.init(%{})

      assert [%Oban.Job{}] = all_enqueued(worker: UpdateWorker)
    end
  end
end
