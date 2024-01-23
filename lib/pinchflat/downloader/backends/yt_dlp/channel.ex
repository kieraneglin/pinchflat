defmodule Pinchflat.Downloader.Backends.YtDlp.Channel do
  @moduledoc """
  Contains utilities for working with a channel's videos
  """

  # TODO: convert to `use`
  import Pinchflat.Downloader.Backends.YtDlp.VideoCollection
  alias __MODULE__

  defstruct [:id, :name]

  def new(id, name) do
    %__MODULE__{id: id, name: name}
  end

  def get_channel_info(channel_url) do
    opts = [print: "%(.{channel,channel_id})j", playlist_end: 1]

    case backend_runner().run(channel_url, opts) do
      {:ok, output} ->
        result = Phoenix.json_library().decode!(output)

        {:ok, Channel.new(result["channel_id"], result["channel"])}

      res ->
        res
    end
  end

  defp backend_runner do
    Application.get_env(:pinchflat, :yt_dlp_runner)
  end
end
