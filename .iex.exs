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
alias Pinchflat.SettingsBackup

alias Pinchflat.Downloading.MediaDownloader
alias Pinchflat.YtDlp.Media, as: YtDlpMedia
alias Pinchflat.YtDlp.MediaCollection, as: YtDlpCollection

alias Pinchflat.FastIndexing.YoutubeRss
alias Pinchflat.Metadata.MetadataFileHelpers

alias Pinchflat.SlowIndexing.FileFollowerServer

Pinchflat.Release.check_file_permissions()
