defmodule Pinchflat.StartupTasksTest do
  use Pinchflat.DataCase

  alias Pinchflat.Settings

  # Since this runs on app boot (even in the test env),
  # any actions in the `init/1` function will already have
  # run. So we can only test the side effects of those actions,
  # rather than the actions themselves.

  describe "apply_default_settings" do
    test "sets default settings" do
      assert Settings.get!(:onboarding) == true
    end
  end
end
