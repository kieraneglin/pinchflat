defmodule Pinchflat.MediaClient.SourceDetails do
  @moduledoc """
  This is the integration layer for actually working with sources.

  Technically hardcodes the yt-dlp backend for now, but should leave
  it open-ish for future expansion (just in case).
  """

  alias Pinchflat.Repo
  alias Pinchflat.MediaSource.Source

  alias Pinchflat.MediaClient.Backends.YtDlp.VideoCollection, as: YtDlpSource
  alias Pinchflat.Profiles.Options.YtDlp.IndexOptionBuilder, as: YtDlpIndexOptionBuilder

  @doc """
  Gets a source's ID and name from its URL using the given backend.

  Returns {:ok, map()} | {:error, any, ...}.
  """
  def get_source_details(source_url, backend \\ :yt_dlp) do
    source_module(backend).get_source_details(source_url)
  end

  @doc """
  Returns a list of video IDs for the given source URL OR source record using the given backend.

  If passing a source record, the call to the backend may have custom options applied based on
  the `option_builder`.

  Returns {:ok, list(binary())} | {:error, any, ...}.
  """
  def get_video_ids(sourceable, backend \\ :yt_dlp)

  def get_video_ids(%Source{} = source, backend) do
    media_profile = Repo.preload(source, :media_profile).media_profile
    {:ok, options} = option_builder(backend).build(media_profile)

    source_module(backend).get_video_ids(source.collection_id, options)
  end

  def get_video_ids(source_url, backend) when is_binary(source_url) do
    source_module(backend).get_video_ids(source_url)
  end

  defp source_module(backend) do
    case backend do
      :yt_dlp -> YtDlpSource
    end
  end

  defp option_builder(backend) do
    case backend do
      :yt_dlp -> YtDlpIndexOptionBuilder
    end
  end
end
