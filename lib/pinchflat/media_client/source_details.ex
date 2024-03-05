defmodule Pinchflat.MediaClient.SourceDetails do
  @moduledoc """
  This is the integration layer for actually working with sources.

  Technically hardcodes the yt-dlp backend for now, but should leave
  it open-ish for future expansion (just in case).
  """

  alias Pinchflat.Sources.Source
  alias Pinchflat.MediaClient.Backends.YtDlp.MediaCollection, as: YtDlpSource

  @doc """
  Gets a source's ID and name from its URL using the given backend.

  Returns {:ok, map()} | {:error, any, ...}.
  """
  def get_source_details(source_url, backend \\ :yt_dlp) do
    source_module(backend).get_source_details(source_url)
  end

  @doc """
  Returns a list of basic media data maps for the given source URL OR
  source record using the given backend.

  Options:
    - :file_listener_handler - a function that will be called with the path to the
      file that will be written to by yt-dlp. This is useful for
      setting up a file watcher to read the file as it gets written to.

  Returns {:ok, [map()]} | {:error, any, ...}.
  """
  def get_media_attributes(sourceable, opts \\ [], backend \\ :yt_dlp)

  def get_media_attributes(%Source{} = source, opts, backend) do
    get_media_attributes(source.collection_id, opts, backend)
  end

  def get_media_attributes(source_url, opts, backend) when is_binary(source_url) do
    source_module(backend).get_media_attributes(source_url, opts)
  end

  defp source_module(backend) do
    case backend do
      :yt_dlp -> YtDlpSource
    end
  end
end
