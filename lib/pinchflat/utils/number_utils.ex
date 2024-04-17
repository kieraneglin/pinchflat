defmodule Pinchflat.Utils.NumberUtils do
  @moduledoc """
  Utility methods for working with numbers
  """

  @doc """
  Clamps a number between a minimum and maximum value

  Returns integer() | float()
  """
  def clamp(num, minimum, maximum) do
    num
    |> max(minimum)
    |> min(maximum)
  end
end
