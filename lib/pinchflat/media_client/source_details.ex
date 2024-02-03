defmodule Pinchflat.MediaClient.SourceDetails do
  @moduledoc """
  This is the integration layer for actually working with sources.

  Technically hardcodes the yt-dlp backend for now, but should leave
  it open-ish for future expansion (just in case).
  """
  @enforce_keys [:id, :name]
  defstruct [:id, :name]

  alias Pinchflat.MediaClient.Backends.YtDlp.VideoCollection, as: YtDlpSource

  @doc false
  def new(id, name) do
    %__MODULE__{id: id, name: name}
  end

  @doc """
  Gets a source's ID and name from its URL, using the given backend.

  Returns {:ok, map()} | {:error, any, ...}.
  """
  def get_source_details(source_url, backend \\ :yt_dlp) do
    source_module(backend).get_source_details(source_url)
  end

  @doc """
  Returns a list of video IDs for the given source URL, using the given backend.

  Returns {:ok, list(binary())} | {:error, any, ...}.
  """
  def get_video_ids(source_url, backend \\ :yt_dlp) do
    source_module(backend).get_video_ids(source_url)
  end

  defp source_module(backend) do
    case backend do
      :yt_dlp -> YtDlpSource
    end
  end
end
