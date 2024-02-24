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
    Map.new()
    |> Map.merge(parse_media_metadata(metadata))
    |> Map.merge(parse_subtitle_metadata(metadata))
    |> Map.merge(parse_thumbnail_metadata(metadata))
    |> Map.merge(parse_infojson_metadata(metadata))
  end

  defp parse_media_metadata(metadata) do
    %{
      title: metadata["title"],
      description: metadata["description"],
      media_filepath: metadata["filepath"]
    }
  end

  defp parse_subtitle_metadata(metadata) do
    subtitle_filepaths =
      (metadata["requested_subtitles"] || %{})
      |> Enum.map(fn {lang, attrs} -> [lang, attrs["filepath"]] end)
      |> Enum.sort(fn [lang_a, _], [lang_b, _] -> lang_a < lang_b end)

    %{
      subtitle_filepaths: subtitle_filepaths
    }
  end

  defp parse_thumbnail_metadata(metadata) do
    thumbnail_filepath =
      (metadata["thumbnails"] || %{})
      # Reverse so that higher resolution thumbnails come first.
      # This _shouldn't_ matter yet, but I'd rather default to the best
      # in case I'm wrong.
      |> Enum.reverse()
      |> Enum.find_value(fn attrs -> attrs["filepath"] end)

    %{
      thumbnail_filepath: thumbnail_filepath
    }
  end

  defp parse_infojson_metadata(metadata) do
    %{
      metadata_filepath: metadata["infojson_filename"]
    }
  end
end
