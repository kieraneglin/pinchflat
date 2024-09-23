defmodule Pinchflat.Utils.MapUtils do
  @moduledoc """
  Utility methods for working with maps
  """

  @doc """
  Converts a nested list of 2-element tuples or lists into a map.

  Returns map()
  """
  def from_nested_list(list) do
    Enum.reduce(list, %{}, fn
      [key, value], acc -> Map.put(acc, key, value)
      {key, value}, acc -> Map.put(acc, key, value)
    end)
  end
end
