defmodule Pinchflat.Downloading.OutputPath.Parser do
  @moduledoc """
  Parses liquid-ish-style strings into a rendered string

  Used for turning filepath templates into real filepaths
  """

  use Pinchflat.Downloading.OutputPath.Base

  @doc """
  Parses a string into a rendered string, using the provided variables. Optionally
  takes a custom fetcher function for handling missing variables.

  Variable identifiers are surrounded by {{ and }}. The variable keys MUST be strings.
  If an identifier is not found in the provided variables, it will be removed from the string.

  Returns `{:ok, binary()}` or `{:error, binary()}`.
  """
  def parse(string, variables, value_fetch_fn \\ &default_fetcher/2) do
    # `do_parse` comes from `RenderedString.Base`
    case do_parse(string) do
      {:ok, parsed, _, _, _, _} ->
        {:ok, build_string(parsed, variables, value_fetch_fn)}

      {:error, message, _, _, _, _} ->
        {:error, message}
    end
  end

  defp build_string(parsed, variables, value_fetch_fn) do
    Enum.reduce(parsed, "", fn element, acc ->
      case element do
        {:text, text} -> acc <> text
        {:interpolation, {:identifier, identifier}} -> acc <> value_fetch_fn.(identifier, variables)
      end
    end)
  end

  def default_fetcher(identifier, variables) do
    Map.get(variables, identifier, "")
  end
end
