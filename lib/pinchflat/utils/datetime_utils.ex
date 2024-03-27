defmodule Pinchflat.Utils.DatetimeUtils do
  @moduledoc """
  Utility methods for working with dates and datetimes
  """

  @doc """
  Converts a Date to a DateTime

  Returns %DateTime{}
  """
  def date_to_datetime(date) do
    date
    |> Date.to_gregorian_days()
    |> Kernel.*(86_400)
    |> DateTime.from_gregorian_seconds()
  end
end
