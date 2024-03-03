defmodule Pinchflat.MediaClient.Backends.BackendCommandRunner do
  @moduledoc """
  A behaviour for running CLI commands against a downloader backend
  """

  @callback run(binary(), keyword(), binary()) :: {:ok, binary()} | {:error, binary(), integer()}
  @callback run(binary(), keyword(), binary(), keyword()) :: {:ok, binary()} | {:error, binary(), integer()}
end
