defmodule Pinchflat.YtDlp.Backend.BackendCommandRunner do
  @moduledoc """
  A behaviour for running CLI commands against a downloader backend (yt-dlp).

  Used so we can implement Mox for testing without actually running the
  yt-dlp command.
  """

  @callback run(binary(), keyword(), binary()) :: {:ok, binary()} | {:error, binary(), integer()}
  @callback run(binary(), keyword(), binary(), keyword()) :: {:ok, binary()} | {:error, binary(), integer()}
end
