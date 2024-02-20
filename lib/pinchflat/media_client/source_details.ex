defmodule Pinchflat.MediaClient.SourceDetails do
  @moduledoc """
  This is the integration layer for actually working with sources.

  Technically hardcodes the yt-dlp backend for now, but should leave
  it open-ish for future expansion (just in case).
  """

  alias Pinchflat.Sources.Source
  alias Pinchflat.MediaClient.Backends.YtDlp.VideoCollection, as: YtDlpSource

  @doc """
  Gets a source's ID and name from its URL using the given backend.

  Returns {:ok, map()} | {:error, any, ...}.
  """
  def get_source_details(source_url, backend \\ :yt_dlp) do
    source_module(backend).get_source_details(source_url)
  end

  @doc """
  Returns a list of basic video data mapsfor the given source URL OR
  source record using the given backend.

  Returns {:ok, [map()]} | {:error, any, ...}.
  """
  def get_media_attributes(sourceable, backend \\ :yt_dlp)

  def get_media_attributes(%Source{} = source, backend) do
    source_module(backend).get_media_attributes(source.collection_id)
  end

  def get_media_attributes(source_url, backend) when is_binary(source_url) do
    source_module(backend).get_media_attributes(source_url)
  end

  defp source_module(backend) do
    case backend do
      :yt_dlp -> YtDlpSource
    end
  end
end
