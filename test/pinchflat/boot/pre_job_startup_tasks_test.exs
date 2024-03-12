defmodule Pinchflat.Boot.PreJobStartupTasksTest do
  use Pinchflat.DataCase

  alias Pinchflat.Settings
  alias Pinchflat.Settings.Setting
  alias Pinchflat.Boot.PreJobStartupTasks

  describe "apply_default_settings" do
    setup do
      Repo.delete_all(Setting)

      :ok
    end

    test "sets default settings" do
      assert_raise Ecto.NoResultsError, fn -> Settings.get!(:onboarding) end
      assert_raise Ecto.NoResultsError, fn -> Settings.get!(:pro_enabled) end

      PreJobStartupTasks.start_link()

      assert Settings.get!(:onboarding)
      refute Settings.get!(:pro_enabled)
    end
  end
end
