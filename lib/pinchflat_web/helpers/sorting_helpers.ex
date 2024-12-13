defmodule PinchflatWeb.Helpers.SortingHelpers do
  @moduledoc """
  Methods for working with sorting, usually in the context of LiveViews or LiveComponents.

  These methods are fairly simple, but they're commonly repeated across different Live entities
  """

  @doc """
  Given the old sort attribute, the new sort attribute, and the old sort direction, returns the new sort direction.

  Returns :asc | :desc
  """
  def get_sort_direction(old_sort_attr, new_sort_attr, old_sort_direction) do
    case {new_sort_attr, old_sort_direction} do
      {^old_sort_attr, :desc} -> :asc
      {^old_sort_attr, _} -> :desc
      _ -> :asc
    end
  end
end
