defmodule Pinchflat.MediaClient.VideoDownloader do
  @moduledoc """
  This is the integration layer for actually downloading videos.
  It takes into account the media profile's settings in order
  to download the video with the desired options.

  Technically hardcodes the yt-dlp backend for now, but should leave
  it open-ish for future expansion (just in case).
  """

  alias Pinchflat.Repo
  alias Pinchflat.Media
  alias Pinchflat.Media.MediaItem
  alias Pinchflat.Profiles.MediaProfile

  alias Pinchflat.MediaClient.Backends.YtDlp.Video, as: YtDlpVideo
  alias Pinchflat.Profiles.Options.YtDlp.OptionBuilder, as: YtDlpOptionBuilder
  alias Pinchflat.MediaClient.Backends.YtDlp.MetadataParser, as: YtDlpMetadataParser

  @doc """
  Downloads a single video based on the settings in the given media profile.

  Returns {:ok, map()} | {:error, any, ...}.
  """
  def download_for_media_profile(url, %MediaProfile{} = media_profile, backend \\ :yt_dlp) do
    option_builder = option_builder(backend)
    video_backend = video_backend(backend)
    {:ok, options} = option_builder.build(media_profile)

    video_backend.download(url, options)
  end

  @doc """
  TODO: test
  TODO: consider removing the above function? I don't know if it's actually useful
  TODO: save metadata filepath to media item record
  TODO: consider saving the output JSON to the database instead of the filesystem.
        reason: would make updating metadata easier (no orphans). Also queryable.
  """
  def download_for_media_item(%MediaItem{} = media_item, backend \\ :yt_dlp) do
    item_with_preloads = Repo.preload(media_item, channel: :media_profile)
    media_profile = item_with_preloads.channel.media_profile

    case download_for_media_profile(media_item.media_id, media_profile, backend) do
      {:ok, parsed_json} ->
        parser = metadata_parser(backend)
        parsed_attrs = parser.parse_for_media_item(parsed_json)

        Media.update_media_item(media_item, parsed_attrs)

      err ->
        err
    end
  end

  defp option_builder(backend) do
    case backend do
      :yt_dlp -> YtDlpOptionBuilder
    end
  end

  defp video_backend(backend) do
    case backend do
      :yt_dlp -> YtDlpVideo
    end
  end

  defp metadata_parser(backend) do
    case backend do
      :yt_dlp -> YtDlpMetadataParser
    end
  end
end
