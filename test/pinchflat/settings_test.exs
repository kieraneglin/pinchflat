defmodule Pinchflat.SettingsBackupTest do
  use Pinchflat.DataCase

  alias Pinchflat.SettingsBackup
  alias Pinchflat.SettingsBackup.SettingBackup

  # NOTE: We're treating some of these tests differently
  # than in other modules because certain settings
  # are always created on app boot (including in the test env),
  # so we can't treat these like a clean slate.

  describe "list_settings/0" do
    test "returns all settings" do
      SettingsBackup.set!("foo", "bar")
      results = SettingsBackup.list_settings()

      assert Enum.all?(results, fn setting -> match?(%SettingBackup{}, setting) end)
    end
  end

  describe "set/2" do
    test "creates a new setting if one does not exist" do
      original = Repo.aggregate(SettingBackup, :count, :id)
      SettingsBackup.set!("foo", "bar")
      assert Repo.aggregate(SettingBackup, :count, :id) == original + 1
    end

    test "updates an existing setting if one exists" do
      SettingsBackup.set!("foo", "bar")
      original = Repo.aggregate(SettingBackup, :count, :id)
      SettingsBackup.set!("foo", "baz")
      assert Repo.aggregate(SettingBackup, :count, :id) == original
      assert SettingsBackup.get!("foo") == "baz"
    end

    test "returns the parsed value" do
      assert SettingsBackup.set!("foo", true) == true
      assert SettingsBackup.set!("foo", false) == false
      assert SettingsBackup.set!("foo", 123) == 123
      assert SettingsBackup.set!("foo", 12.34) == 12.34
      assert SettingsBackup.set!("foo", "bar") == "bar"
    end

    test "allows for atom keys" do
      assert SettingsBackup.set!(:foo, "bar") == "bar"
    end

    test "blows up when an unsupported datatype is used" do
      assert_raise FunctionClauseError, fn ->
        SettingsBackup.set!("foo", nil)
      end
    end
  end

  describe "set/3" do
    test "allows manual specification of datatype" do
      assert SettingsBackup.set!("foo", "true", :boolean) == true
      assert SettingsBackup.set!("foo", "false", :boolean) == false
      assert SettingsBackup.set!("foo", "123", :integer) == 123
      assert SettingsBackup.set!("foo", "12.34", :float) == 12.34
    end
  end

  describe "get/1" do
    test "returns the value of the setting" do
      SettingsBackup.set!("str", "bar")
      SettingsBackup.set!("bool", true)
      SettingsBackup.set!("int", 123)
      SettingsBackup.set!("float", 12.34)

      assert SettingsBackup.get!("str") == "bar"
      assert SettingsBackup.get!("bool") == true
      assert SettingsBackup.get!("int") == 123
      assert SettingsBackup.get!("float") == 12.34
    end

    test "allows for atom keys" do
      SettingsBackup.set!("str", "bar")
      assert SettingsBackup.get!(:str) == "bar"
    end

    test "blows up when the setting does not exist" do
      assert_raise Ecto.NoResultsError, fn ->
        SettingsBackup.get!("foo")
      end
    end
  end

  describe "fetch/2" do
    test "creates a setting if one doesn't exist" do
      original = Repo.aggregate(SettingBackup, :count, :id)
      assert SettingsBackup.fetch!("foo", "bar") == "bar"
      assert Repo.aggregate(SettingBackup, :count, :id) == original + 1
    end

    test "returns an existing setting if one does exist" do
      SettingsBackup.set!("foo", "bar")

      assert SettingsBackup.fetch!("foo", "baz") == "bar"
    end
  end

  describe "fetch/3" do
    test "allows manual specification of datatype" do
      assert SettingsBackup.fetch!("foo", "true", :boolean) == true
    end
  end
end
