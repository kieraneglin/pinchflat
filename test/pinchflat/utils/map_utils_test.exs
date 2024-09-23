defmodule Pinchflat.Utils.MapUtilsTest do
  use Pinchflat.DataCase

  alias Pinchflat.Utils.MapUtils

  describe "from_nested_list/1" do
    test "creates a map from a nested 2-element tuple list" do
      list = [
        {"key1", "value1"},
        {"key2", "value2"}
      ]

      assert MapUtils.from_nested_list(list) == %{
               "key1" => "value1",
               "key2" => "value2"
             }
    end

    test "creates a map from a nested 2-element list of lists" do
      list = [
        ["key1", "value1"],
        ["key2", "value2"]
      ]

      assert MapUtils.from_nested_list(list) == %{
               "key1" => "value1",
               "key2" => "value2"
             }
    end
  end
end
