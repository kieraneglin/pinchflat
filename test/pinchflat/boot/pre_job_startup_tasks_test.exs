defmodule Pinchflat.Boot.PreJobStartupTasksTest do
  use Pinchflat.DataCase

  alias Pinchflat.SettingsBackup
  alias Pinchflat.SettingsBackup.SettingBackup
  alias Pinchflat.Boot.PreJobStartupTasks

  describe "apply_default_settings" do
    setup do
      Repo.delete_all(SettingBackup)

      :ok
    end

    test "sets default settings" do
      assert_raise Ecto.NoResultsError, fn -> SettingsBackup.get!(:onboarding) end
      assert_raise Ecto.NoResultsError, fn -> SettingsBackup.get!(:pro_enabled) end

      PreJobStartupTasks.start_link()

      assert SettingsBackup.get!(:onboarding)
      refute SettingsBackup.get!(:pro_enabled)
    end
  end
end
