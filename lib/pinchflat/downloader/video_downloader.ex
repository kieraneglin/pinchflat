defmodule Pinchflat.Downloader.VideoDownloader do
  @moduledoc """
  This is the integration layer for actually downloading videos.
  It takes into account the media profile's settings in order
  to download the video with the desired options.

  Technically hardcodes the yt-dlp backend for now, but should leave
  it open-ish for future expansion (just in case).
  """

  alias Pinchflat.Downloader.Backends.YtDlp.Video, as: YtDlpVideo
  alias Pinchflat.Profiles.Options.YtDlp.OptionBuilder, as: YtDlpOptionBuilder

  @doc """
  Downloads a single video based on the settings in the given media profile.

  # TODO: implement media profiles - so far this is a glorified mock
  # TODO: test
  """
  def download_for_media_profile(url, media_profile, backend \\ :yt_dlp) do
    option_builder = option_builder(backend)
    video_backend = video_backend(backend)
    {:ok, options} = option_builder.build(media_profile)

    video_backend.download(url, options)
  end

  def option_builder(backend) do
    case backend do
      :yt_dlp -> YtDlpOptionBuilder
    end
  end

  def video_backend(backend) do
    case backend do
      :yt_dlp -> YtDlpVideo
    end
  end
end
