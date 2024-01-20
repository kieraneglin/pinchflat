defmodule Pinchflat.DownloaderBackends.YtDlp.VideoCollection do
  @moduledoc """
  Contains utilities for working with collections of videos (ie: channels, playlists)
  """

  @doc """
  Returns a list of strings representing the video ids in the collection
  """
  def get_video_ids(url, command_opts \\ []) do
    opts = command_opts ++ [:simulate, :skip_download, :get_id]

    case backend_runner().run(url, opts) do
      {:ok, output} -> {:ok, String.split(output, "\n", trim: true)}
      res -> res
    end
  end

  defp backend_runner do
    Application.get_env(:pinchflat, :yt_dlp_runner)
  end
end
