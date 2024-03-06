defmodule Pinchflat.SettingsTest do
  use Pinchflat.DataCase

  alias Pinchflat.Settings
  alias Pinchflat.Settings.Setting

  describe "list_settings/0" do
    test "returns all settings" do
      Settings.set!("foo", "bar")
      assert [_] = Settings.list_settings()
    end
  end

  describe "set/2" do
    test "creates a new setting if one does not exist" do
      assert Repo.aggregate(Setting, :count, :id) == 0
      Settings.set!("foo", "bar")
      assert Repo.aggregate(Setting, :count, :id) == 1
    end

    test "updates an existing setting if one exists" do
      Settings.set!("foo", "bar")
      assert Repo.aggregate(Setting, :count, :id) == 1
      Settings.set!("foo", "baz")
      assert Repo.aggregate(Setting, :count, :id) == 1
      assert Settings.get!("foo") == "baz"
    end

    test "returns the parsed value" do
      assert Settings.set!("foo", true) == true
      assert Settings.set!("foo", false) == false
      assert Settings.set!("foo", 123) == 123
      assert Settings.set!("foo", 12.34) == 12.34
      assert Settings.set!("foo", "bar") == "bar"
    end

    test "allows for atom keys" do
      assert Settings.set!(:foo, "bar") == "bar"
    end

    test "blows up when an unsupported datatype is used" do
      assert_raise FunctionClauseError, fn ->
        Settings.set!("foo", nil)
      end
    end
  end

  describe "set/3" do
    test "allows manual specification of datatype" do
      assert Settings.set!("foo", "true", :boolean) == true
      assert Settings.set!("foo", "false", :boolean) == false
      assert Settings.set!("foo", "123", :integer) == 123
      assert Settings.set!("foo", "12.34", :float) == 12.34
    end
  end

  describe "get/1" do
    test "returns the value of the setting" do
      Settings.set!("str", "bar")
      Settings.set!("bool", true)
      Settings.set!("int", 123)
      Settings.set!("float", 12.34)

      assert Settings.get!("str") == "bar"
      assert Settings.get!("bool") == true
      assert Settings.get!("int") == 123
      assert Settings.get!("float") == 12.34
    end

    test "allows for atom keys" do
      Settings.set!("str", "bar")
      assert Settings.get!(:str) == "bar"
    end

    test "blows up when the setting does not exist" do
      assert_raise Ecto.NoResultsError, fn ->
        Settings.get!("foo")
      end
    end
  end
end
