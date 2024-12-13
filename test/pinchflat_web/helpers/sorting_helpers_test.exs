defmodule PinchflatWeb.Helpers.SortingHelpersTest do
  use Pinchflat.DataCase

  alias PinchflatWeb.Helpers.SortingHelpers

  describe "get_sort_direction/3" do
    test "returns the correct sort direction when the new sort attribute is the same as the old sort attribute" do
      old_sort_attr = "name"
      new_sort_attr = "name"
      old_sort_direction = :desc

      assert SortingHelpers.get_sort_direction(old_sort_attr, new_sort_attr, old_sort_direction) == :asc
    end

    test "returns the correct sort direction when the new sort attribute is the same as the old sort attribute in the other direction" do
      old_sort_attr = "name"
      new_sort_attr = "name"
      old_sort_direction = :asc

      assert SortingHelpers.get_sort_direction(old_sort_attr, new_sort_attr, old_sort_direction) == :desc
    end

    test "returns the correct sort direction when the new sort attribute is different from the old sort attribute" do
      old_sort_attr = "name"
      new_sort_attr = "date"
      old_sort_direction = :asc

      assert SortingHelpers.get_sort_direction(old_sort_attr, new_sort_attr, old_sort_direction) == :asc
    end
  end
end
