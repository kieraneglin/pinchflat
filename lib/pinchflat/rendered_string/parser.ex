defmodule Pinchflat.RenderedString.Parser do
  @moduledoc """
  Parses liquid-ish-style strings into a rendered string

  Used for turning filepath templates into real filepaths
  """

  use Pinchflat.RenderedString.Base

  @doc """
  Parses a string into a rendered string, using the provided variables.

  Variable identifiers are surrounded by {{ and }}. The variable keys MUST be strings.
  If an identifier is not found in the provided variables, it will be removed from the string.
  """
  def parse(string, variables) do
    # `do_parse` comes from `RenderedString.Base`
    case do_parse(string) do
      {:ok, parsed, _, _, _, _} ->
        {:ok, build_string(parsed, variables)}

      {:error, message, _, _, _, _} ->
        {:error, message}
    end
  end

  defp build_string(parsed, variables) do
    Enum.reduce(parsed, "", fn element, acc ->
      case element do
        {:text, text} -> acc <> text
        {:interpolation, {:identifier, identifier}} -> acc <> to_string(variables[identifier])
      end
    end)
  end
end
