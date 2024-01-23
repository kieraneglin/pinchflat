defmodule Pinchflat.MediaClient.ChannelDetails do
  @moduledoc """
  This is the integration layer for actually working with channels.

  Technically hardcodes the yt-dlp backend for now, but should leave
  it open-ish for future expansion (just in case).
  """
  @enforce_keys [:id, :name]
  defstruct [:id, :name]

  alias Pinchflat.MediaClient.Backends.YtDlp.Channel, as: YtDlpChannel

  @doc false
  def new(id, name) do
    %__MODULE__{id: id, name: name}
  end

  @doc """
  Gets a channel's ID and name from its URL, using the given backend.

  Returns {:ok, map()} | {:error, any, ...}.
  """
  def get_channel_details(channel_url, backend \\ :yt_dlp) do
    channel_module(backend).get_channel_info(channel_url)
  end

  defp channel_module(backend) do
    case backend do
      :yt_dlp -> YtDlpChannel
    end
  end
end
