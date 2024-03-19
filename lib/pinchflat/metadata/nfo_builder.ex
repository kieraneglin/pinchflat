defmodule Pinchflat.Metadata.NfoBuilder do
  @moduledoc """
  Provides methods for building and storing NFO files for
  use by Kodi/Jellyfin and other media center software.
  """

  alias Pinchflat.Metadata.MetadataFileHelpers
  alias Pinchflat.Filesystem.FilesystemHelpers

  @doc """
  Builds an NFO file for a media item (read: single "episode") and
  stores it at the specified location.

  Returns the filepath of the NFO file.
  """
  def build_and_store_for_media_item(filepath, metadata) do
    nfo = build_for_media_item(metadata)

    FilesystemHelpers.write_p!(filepath, nfo)

    filepath
  end

  @doc """
  Builds an NFO file for a souce and stores it at the specified location.
  Technically works for playlists, but it's really made for channels.

  Returns the filepath of the NFO file.
  """
  def build_and_store_for_source(filepath, metadata) do
    nfo = build_for_source(metadata)

    FilesystemHelpers.write_p!(filepath, nfo)

    filepath
  end

  defp build_for_media_item(metadata) do
    upload_date = MetadataFileHelpers.parse_upload_date(metadata["upload_date"])
    # Cribbed from a combination of the Kodi wiki, ytdl-nfo, and ytdl-sub.
    # WHO NEEDS A FANCY XML PARSER ANYWAY?!
    """
    <?xml version="1.0" encoding="UTF-8" standalone="yes" ?>
    <episodedetails>
      <title>#{metadata["title"]}</title>
      <showtitle>#{metadata["uploader"]}</showtitle>
      <uniqueid type="youtube" default="true">#{metadata["id"]}</uniqueid>
      <plot>#{metadata["description"]}</plot>
      <aired>#{upload_date}</aired>
      <season>#{upload_date.year}</season>
      <episode>#{Calendar.strftime(upload_date, "%m%d")}</episode>
      <genre>YouTube</genre>
    </episodedetails>
    """
  end

  defp build_for_source(metadata) do
    """
    <?xml version="1.0" encoding="UTF-8" standalone="yes" ?>
    <tvshow>
      <title>#{metadata["title"]}</title>
      <plot>#{metadata["description"]}</plot>
      <uniqueid type="youtube" default="true">#{metadata["id"]}</uniqueid>
      <genre>YouTube</genre>
    </tvshow>
    """
  end
end
