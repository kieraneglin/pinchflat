defmodule Pinchflat.MediaClient.Backends.YtDlp.MetadataParser do
  @moduledoc """
  yt-dlp offers a LOT of metadata in its JSON response, some of which
  needs to be extracted and included in various models.

  For now, also squirrel all of it away in the `media_metadata` table.
  I might revisit this or pare it down later, but I'd rather need it
  and not have it, ya know?
  """

  @doc """
  Parses the given JSON response from yt-dlp and returns a map of
  the needful media_item attributes, along with anything needed for
  its associations.

  Returns map()
  """
  def parse_for_media_item(metadata) do
    %{
      video_filepath: metadata["filepath"],
      metadata: %{
        client_response: metadata
      }
    }
  end
end
