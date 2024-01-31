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
    metadata_attrs = %{
      metadata: %{
        client_response: metadata
      }
    }

    metadata_attrs
    |> Map.merge(parse_media_metadata(metadata))
    |> Map.merge(parse_subtitle_metadata(metadata))
  end

  defp parse_media_metadata(metadata) do
    %{
      title: metadata["title"],
      video_filepath: metadata["filepath"]
    }
  end

  defp parse_subtitle_metadata(metadata) do
    subtitle_map = metadata["requested_subtitles"] || %{}
    # IDEA: if needed, consider filtering out subtitles that don't exist on-disk
    subtitle_filepaths =
      subtitle_map
      |> Enum.map(fn {lang, attrs} -> [lang, attrs["filepath"]] end)
      |> Enum.sort(fn [lang_a, _], [lang_b, _] -> lang_a < lang_b end)

    %{
      subtitle_filepaths: subtitle_filepaths
    }
  end
end
