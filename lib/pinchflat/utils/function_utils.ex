defmodule Pinchflat.Utils.FunctionUtils do
  @moduledoc """
  Utility functions for working with functions
  """

  @doc """
  Wraps the provided term in an :ok tuple. Useful for fulfilling a contract, but
  other usage should be assessed to see if it's the right fit.

  Returns {:ok, term}
  """
  def wrap_ok(value) do
    {:ok, value}
  end
end
