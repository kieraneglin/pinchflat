defmodule Pinchflat.MediaClient.Backends.BackendCommandRunner do
  @moduledoc """
  A behaviour for running CLI commands against a downloader backend
  """

  @callback run(binary(), keyword()) :: {:ok, binary()} | {:error, binary(), integer()}
end
