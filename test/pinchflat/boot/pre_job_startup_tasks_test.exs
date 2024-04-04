defmodule Pinchflat.Boot.PreJobStartupTasksTest do
  use Pinchflat.DataCase

  alias Pinchflat.Settings
  alias Pinchflat.Boot.PreJobStartupTasks

  # TODO: write tests for things like cookie file creation

  describe "apply_default_settings" do
    setup do
      Settings.set(yt_dlp_version: nil)

      :ok
    end

    test "sets default settings" do
      assert Settings.get!(:yt_dlp_version) == nil

      PreJobStartupTasks.start_link()

      assert Settings.get!(:yt_dlp_version)
    end
  end
end
