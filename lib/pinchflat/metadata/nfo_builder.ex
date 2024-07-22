defmodule Pinchflat.Metadata.NfoBuilder do
  @moduledoc """
  Provides methods for building and storing NFO files for
  use by Kodi/Jellyfin and other media center software.
  """

  import Pinchflat.Utils.XmlUtils, only: [safe: 1]

  alias Pinchflat.Utils.FilesystemUtils
  alias Pinchflat.Metadata.MetadataFileHelpers

  @doc """
  Builds an NFO file for a media item (read: single "episode") and
  stores it at the specified location.

  Returns the filepath of the NFO file.
  """
  def build_and_store_for_media_item(nfo_filepath, metadata) do
    nfo = build_for_media_item(nfo_filepath, metadata)

    FilesystemUtils.write_p!(nfo_filepath, nfo)

    nfo_filepath
  end

  @doc """
  Builds an NFO file for a souce and stores it at the specified location.
  Technically works for playlists, but it's really made for channels.

  Returns the filepath of the NFO file.
  """
  def build_and_store_for_source(filepath, metadata) do
    nfo = build_for_source(metadata)

    FilesystemUtils.write_p!(filepath, nfo)

    filepath
  end

  defp build_for_media_item(nfo_filepath, metadata) do
    upload_date = MetadataFileHelpers.parse_upload_date(metadata["upload_date"])
    # NOTE: the filepath here isn't the path of the media item, it's the path that
    # the NFO should be saved to. This works because the NFO's path is the same as
    # the media's path, just with a different extension. If this ever changes I'll
    # need to pass in the media item's path as well.
    {season, episode} = determine_season_and_episode_number(nfo_filepath, upload_date)

    # Cribbed from a combination of the Kodi wiki, ytdl-nfo, and ytdl-sub.
    """
    <?xml version="1.0" encoding="UTF-8" standalone="yes" ?>
    <episodedetails>
      <title>#{safe(metadata["title"])}</title>
      <showtitle>#{safe(metadata["uploader"])}</showtitle>
      <uniqueid type="youtube" default="true">#{safe(metadata["id"])}</uniqueid>
      <plot>#{safe(metadata["description"])}</plot>
      <aired>#{safe(upload_date)}</aired>
      <season>#{safe(season)}</season>
      <episode>#{episode}</episode>
      <genre>YouTube</genre>
    </episodedetails>
    """
  end

  defp build_for_source(metadata) do
    """
    <?xml version="1.0" encoding="UTF-8" standalone="yes" ?>
    <tvshow>
      <title>#{safe(metadata["title"])}</title>
      <plot>#{safe(metadata["description"])}</plot>
      <uniqueid type="youtube" default="true">#{safe(metadata["id"])}</uniqueid>
      <genre>YouTube</genre>
    </tvshow>
    """
  end

  defp determine_season_and_episode_number(filepath, upload_date) do
    case MetadataFileHelpers.season_and_episode_from_media_filepath(filepath) do
      {:ok, {season, episode}} -> {season, episode}
      {:error, _} -> {upload_date.year, Calendar.strftime(upload_date, "%m%d")}
    end
  end
end
