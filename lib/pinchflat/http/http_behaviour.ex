defmodule Pinchflat.HTTP.HTTPBehaviour do
  @moduledoc """
  This module defines the behaviour for HTTP clients. Literally just
  so I can use Mox to create an HTTP mock
  """

  @callback get(String.t(), Keyword.t(), Keyword.t()) :: {:ok, String.t()} | {:error, String.t()}
end
