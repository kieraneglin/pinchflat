defmodule Pinchflat.Utils.XmlUtils do
  @moduledoc """
  Utility methods for working with XML documents
  """

  @doc """
  Escapes invalid XML characters in a string

  Returns binary()
  """
  def safe(value) do
    value
    |> to_string()
    |> Phoenix.HTML.html_escape()
    |> Phoenix.HTML.safe_to_string()
  end
end
