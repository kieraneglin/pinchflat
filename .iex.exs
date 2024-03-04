alias Pinchflat.Repo

alias Pinchflat.Tasks.Task
alias Pinchflat.Media.MediaItem
alias Pinchflat.Tasks.SourceTasks
alias Pinchflat.Media.MediaMetadata
alias Pinchflat.Sources.Source
alias Pinchflat.Profiles.MediaProfile

alias Pinchflat.Tasks
alias Pinchflat.Media
alias Pinchflat.Profiles
alias Pinchflat.Sources

alias Pinchflat.MediaClient.{SourceDetails, VideoDownloader}
alias Pinchflat.Metadata.{Zipper, ThumbnailFetcher}

alias Pinchflat.Utils.FilesystemUtils.FileFollowerServer

defmodule IexHelpers do
  def playlist_url do
    "https://www.youtube.com/playlist?list=PLmqC3wPkeL8kSlTCcSMDD63gmSi7evcXS"
  end

  def channel_url do
    "https://www.youtube.com/c/TheUselessTrials"
  end

  def video_url do
    "https://www.youtube.com/watch?v=bR52O78ZIUw"
  end

  def details(type) do
    source =
      case type do
        :playlist -> playlist_url()
        :channel -> channel_url()
      end

    SourceDetails.get_source_details(source)
  end

  def ids(type) do
    source =
      case type do
        :playlist -> playlist_url()
        :channel -> channel_url()
      end

    SourceDetails.get_media_attributes(source)
  end
end

import IexHelpers
