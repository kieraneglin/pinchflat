defmodule Pinchflat.Downloader.Filepath.Parser do
  @moduledoc """
  A behaviour for running CLI commands against a downloader backend
  """

  @callback run(binary(), keyword()) :: {:ok, binary()} | {:error, binary(), integer()}
end
