defmodule Pinchflat.Utils.StringUtils do
  @moduledoc """
  Utility functions for working with strings
  """

  @doc """
  Converts a string to kebab-case (ie: `hello world` -> `hello-world`)
  """
  def to_kebab_case(string) do
    string
    |> String.replace(~r/[\s_]/, "-")
    |> String.downcase()
  end
end
