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

  @doc """
  TODO: test
  """
  def random_string(length \\ 32) do
    :crypto.strong_rand_bytes(length)
    |> Base.encode16(case: :lower)
    |> String.slice(0..(length - 1))
  end
end
