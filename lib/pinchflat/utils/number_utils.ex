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

  @doc """
  Converts a number to a human readable byte size. Can take a precision
  option to specify the number of decimal places to round to.

  Returns {integer(), String.t()}
  """
  def human_byte_size(number, opts \\ [])
  def human_byte_size(nil, opts), do: human_byte_size(0, opts)

  def human_byte_size(number, opts) do
    precision = Keyword.get(opts, :precision, 2)
    suffixes = ["B", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB"]
    base = 1024

    Enum.reduce_while(suffixes, {number / 1.0, "B"}, fn suffix, {value, _} ->
      if value < base do
        {:halt, {Float.round(value, precision), suffix}}
      else
        {:cont, {value / base, suffix}}
      end
    end)
  end

  @doc """
  Adds jitter to a number based on a percentage. Returns 0 if the number is less than or equal to 0.

  Returns integer()
  """
  def add_jitter(num, jitter_percentage \\ 0.5)
  def add_jitter(num, _jitter_percentage) when num <= 0, do: 0

  def add_jitter(num, jitter_percentage) do
    jitter = :rand.uniform(round(num * jitter_percentage))

    round(num + jitter)
  end
end
