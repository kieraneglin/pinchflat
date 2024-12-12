defmodule PinchflatWeb.Helpers.SortingHelpers do
  # TODO: test
  def get_sort_direction(old_sort_attr, new_sort_attr, old_sort_direction) do
    case {new_sort_attr, old_sort_direction} do
      {^old_sort_attr, :desc} -> :asc
      {^old_sort_attr, _} -> :desc
      _ -> :asc
    end
  end
end
