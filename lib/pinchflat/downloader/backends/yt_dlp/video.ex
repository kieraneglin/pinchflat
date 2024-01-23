defmodule Pinchflat.Downloader.Backends.YtDlp.Video do
  @moduledoc """
  Contains utilities for working with singular videos
  """

  @doc """
  Downloads a single video (and possible metadata) directly to its
  final destination. Returns the parsed JSON output from yt-dlp.
  """
  def download(url, command_opts \\ []) do
    opts = [:no_simulate, print: "%()j"] ++ command_opts

    case backend_runner().run(url, opts) do
      # TODO: test that I changed this to a ! method
      {:ok, output} -> {:ok, Phoenix.json_library().decode!(output)}
      err -> err
    end
  end

  defp backend_runner do
    Application.get_env(:pinchflat, :yt_dlp_runner)
  end
end
