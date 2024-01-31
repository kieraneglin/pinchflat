defmodule Pinchflat.MediaClient.Backends.YtDlp.Video do
  @moduledoc """
  Contains utilities for working with singular videos
  """

  @doc """
  Downloads a single video (and possibly its metadata) directly to its
  final destination. Returns the parsed JSON output from yt-dlp.

  Returns {:ok, map()} | {:error, any, ...}.
  """
  def download(url, command_opts \\ []) do
    opts = [:no_simulate] ++ command_opts

    with {:ok, output} <- backend_runner().run(url, opts, "after_move:%()j"),
         {:ok, parsed_json} <- Phoenix.json_library().decode(output) do
      {:ok, parsed_json}
    else
      err -> err
    end
  end

  defp backend_runner do
    Application.get_env(:pinchflat, :yt_dlp_runner)
  end
end
