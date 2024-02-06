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
  alias Pinchflat.Profiles.Options.YtDlp.DownloadOptionBuilder, as: YtDlpDownloadOptionBuilder
  alias Pinchflat.MediaClient.Backends.YtDlp.MetadataParser, as: YtDlpMetadataParser

  @doc """
  Downloads a video for a media item, updating the media item based on the metadata
  returned by the backend. Also saves the entire metadata response to the associated
  media_metadata record.

  NOTE: related methods (like the download worker) won't download if the source is set
  to not download media. However, I'm not enforcing that here since I need this for testing.
  This may change in the future but I'm not stressed.

  Returns {:ok, %MediaItem{}} | {:error, any, ...any}
  """
  def download_for_media_item(%MediaItem{} = media_item, backend \\ :yt_dlp) do
    item_with_preloads = Repo.preload(media_item, [:metadata, source: :media_profile])
    media_profile = item_with_preloads.source.media_profile

    case download_for_media_profile(media_item.media_id, media_profile, backend) do
      {:ok, parsed_json} ->
        parser = metadata_parser(backend)
        parsed_attrs = parser.parse_for_media_item(parsed_json)

        # Don't forgor to use preloaded associations or updates to
        # associations won't work!
        Media.update_media_item(item_with_preloads, parsed_attrs)

      err ->
        err
    end
  end

  defp download_for_media_profile(url, %MediaProfile{} = media_profile, backend) do
    option_builder = option_builder(backend)
    video_backend = video_backend(backend)
    {:ok, options} = option_builder.build(media_profile)

    video_backend.download(url, options)
  end

  defp option_builder(backend) do
    case backend do
      :yt_dlp -> YtDlpDownloadOptionBuilder
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
