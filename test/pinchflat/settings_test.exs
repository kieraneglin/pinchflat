defmodule Pinchflat.SettingsTest do
  use Pinchflat.DataCase

  alias Pinchflat.Settings
  alias Pinchflat.Settings.Setting

  # NOTE: We're treating some of these tests differently
  # than in other modules because certain settings
  # are always created on app boot (including in the test env),
  # so we can't treat these like a clean slate.

  setup do
    # Ensure we have a clean slate
    Settings.set(onboarding: false)
    Settings.set(pro_enabled: false)
    Settings.set(yt_dlp_version: nil)

    :ok
  end

  describe "record/0" do
    test "returns the only setting" do
      assert %Setting{} = Settings.record()
    end
  end

  describe "update_setting/2" do
    test "updates the setting" do
      setting = Settings.record()

      assert {:ok, false} = Settings.get(:onboarding)
      assert {:ok, %Setting{}} = Settings.update_setting(setting, %{onboarding: true})
      assert {:ok, true} = Settings.get(:onboarding)
    end
  end

  describe "set/1" do
    test "updates the setting" do
      assert {:ok, true} = Settings.set(onboarding: true)
      assert {:ok, true} = Settings.get(:onboarding)
    end

    test "returns an error if the setting key doesn't exist" do
      assert {:error, :invalid_key} = Settings.set(foo: "bar")
    end

    test "returns an error if the setting value is invalid" do
      assert {:error, %Ecto.Changeset{}} = Settings.set(onboarding: "bar")
    end
  end

  describe "get/1" do
    test "returns the setting value" do
      assert {:ok, false} = Settings.get(:onboarding)
    end

    test "returns an error if the setting key doesn't exist" do
      assert {:error, :invalid_key} = Settings.get(:foo)
    end
  end

  describe "get!/1" do
    test "returns the setting value" do
      assert Settings.get!(:onboarding) == false
    end

    test "raises an error if the setting key doesn't exist" do
      assert_raise RuntimeError, "Setting `foo` not found", fn ->
        Settings.get!(:foo)
      end
    end
  end

  describe "change_setting/2" do
    test "returns a changeset" do
      setting = Settings.record()

      assert %Ecto.Changeset{} = Settings.change_setting(setting, %{onboarding: true})
    end

    test "converts (video|audio)_codec_preference_string to an array" do
      setting = Settings.record()

      new_setting = %{
        video_codec_preference_string: "avc>vp9",
        audio_codec_preference_string: "aac>opus"
      }

      changeset = Settings.change_setting(setting, new_setting)

      assert ["avc", "vp9"] = changeset.changes.video_codec_preference
      assert ["aac", "opus"] = changeset.changes.audio_codec_preference
    end
  end

  test "removes whitespace from (video|audio)_codec_preference" do
    setting = Settings.record()

    new_setting = %{
      video_codec_preference_string: "  avc  > >  vp9  ",
      audio_codec_preference_string: "aac> opus "
    }

    changeset = Settings.change_setting(setting, new_setting)

    assert ["avc", "vp9"] = changeset.changes.video_codec_preference
    assert ["aac", "opus"] = changeset.changes.audio_codec_preference
  end

  test "downcases (video|audio)_codec_preference" do
    setting = Settings.record()

    new_setting = %{
      video_codec_preference_string: "AVC>VP9",
      audio_codec_preference_string: "AAC>OPUS"
    }

    changeset = Settings.change_setting(setting, new_setting)

    assert ["avc", "vp9"] = changeset.changes.video_codec_preference
    assert ["aac", "opus"] = changeset.changes.audio_codec_preference
  end
end
