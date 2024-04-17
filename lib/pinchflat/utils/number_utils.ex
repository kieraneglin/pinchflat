defmodule Pinchflat.Utils.NumberUtils do
  @moduledoc """
  Utility methods for working with numbers
  """

  # TODO: test
  def clamp(num, minimum, maximum) do
    num
    |> max(minimum)
    |> min(maximum)
  end
end
