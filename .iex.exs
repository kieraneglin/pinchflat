import Ecto.Query, warn: false
alias Pinchflat.Repo

alias Pinchflat.Tasks.Task
alias Pinchflat.Sources.Source
alias Pinchflat.Media.MediaItem
alias Pinchflat.Metadata.MediaMetadata
alias Pinchflat.Profiles.MediaProfile

alias Pinchflat.Tasks
alias Pinchflat.Media
alias Pinchflat.Profiles
alias Pinchflat.Sources
alias Pinchflat.Settings

alias Pinchflat.Downloading.MediaDownloader
alias Pinchflat.YtDlp.Media, as: YtDlpMedia
alias Pinchflat.YtDlp.MediaCollection, as: YtDlpCollection

alias Pinchflat.FastIndexing.YoutubeRss
alias Pinchflat.Metadata.MetadataFileHelpers

alias Pinchflat.SlowIndexing.FileFollowerServer

defmodule IexHelpers do
  def last_media_item do
    Repo.one(from m in MediaItem, limit: 1)
  end

  def details(type) do
    source =
      case type do
        :playlist -> playlist_url()
        :channel -> channel_url()
      end

    YtDlpCollection.get_source_details(source)
  end

  def ids(type) do
    source =
      case type do
        :playlist -> playlist_url()
        :channel -> channel_url()
      end

    YtDlpCollection.get_media_attributes_for_collection(source)
  end
end

import IexHelpers
