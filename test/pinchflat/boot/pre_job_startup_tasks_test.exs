defmodule Pinchflat.Boot.PreJobStartupTasksTest do
  use Pinchflat.DataCase

  import Pinchflat.JobFixtures

  alias Pinchflat.Settings
  alias Pinchflat.Boot.PreJobStartupTasks

  describe "reset_executing_jobs" do
    test "resets executing jobs" do
      job = job_fixture()
      Repo.update_all(Oban.Job, set: [state: "executing"])

      assert Repo.reload!(job).state == "executing"

      PreJobStartupTasks.start_link()

      assert Repo.reload!(job).state == "retryable"
    end
  end

  describe "create_blank_cookie_file" do
    test "creates a blank cookie file" do
      base_dir = Application.get_env(:pinchflat, :extras_directory)
      filepath = Path.join(base_dir, "cookies.txt")
      File.rm(filepath)

      refute File.exists?(filepath)

      PreJobStartupTasks.start_link()

      assert File.exists?(filepath)
    end
  end

  describe "apply_default_settings" do
    test "sets default settings" do
      Settings.set(yt_dlp_version: nil)

      refute Settings.get!(:yt_dlp_version)

      PreJobStartupTasks.start_link()

      assert Settings.get!(:yt_dlp_version)
    end
  end
end
