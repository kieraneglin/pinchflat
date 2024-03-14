defmodule Pinchflat.Metadata.NfoBuilder do
  @moduledoc """
  Provides methods for building and storing NFO files for
  use by Kodi/Jellyfin and other media center software.
  """

  alias Pinchflat.Metadata.MetadataFileHelpers
  alias Pinchflat.Filesystem.FilesystemHelpers

  @doc """
  Builds an NFO file for a media item (read: single "episode") and
  stores it in the same directory as the media file. Has the same name
  as the media file, but with a .nfo extension.

  Returns the filepath of the NFO file.
  """
  def build_and_store_for_media_item(metadata) do
    filepath = Path.rootname(metadata["filepath"]) <> ".nfo"
    nfo = build_for_media_item(metadata)

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
      <premiered>#{upload_date}</premiered>
      <season>#{upload_date.year}</season>
      <episode>#{Calendar.strftime(upload_date, "%m%d")}</episode>
      <genre>YouTube</genre>
    </episodedetails>
    """
  end
end
