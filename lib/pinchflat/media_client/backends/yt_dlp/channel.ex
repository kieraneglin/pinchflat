defmodule Pinchflat.MediaClient.Backends.YtDlp.Channel do
  @moduledoc """
  Contains utilities for working with a channel's videos
  """

  use Pinchflat.MediaClient.Backends.YtDlp.VideoCollection
  alias Pinchflat.MediaClient.ChannelDetails

  @doc """
  Gets a channel's ID and name from its URL.

  yt-dlp does not _really_ have channel-specific functions, so
  instead we're fetching just the first video (using playlist_end: 1)
  and parsing the channel ID and name from _its_ metadata

  Returns {:ok, %ChannelDetails{}} | {:error, any, ...}.
  """
  def get_channel_info(channel_url) do
    opts = [print: "%(.{channel,channel_id})j", playlist_end: 1]

    with {:ok, output} <- backend_runner().run(channel_url, opts),
         {:ok, parsed_json} <- Phoenix.json_library().decode(output) do
      {:ok, ChannelDetails.new(parsed_json["channel_id"], parsed_json["channel"])}
    else
      err -> err
    end
  end

  defp backend_runner do
    Application.get_env(:pinchflat, :yt_dlp_runner)
  end
end
