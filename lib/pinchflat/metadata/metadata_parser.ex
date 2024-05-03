defmodule Pinchflat.Metadata.MetadataParser do
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
      media_id: metadata["id"],
      title: metadata["title"],
      original_url: metadata["original_url"],
      description: metadata["description"],
      media_filepath: metadata["filepath"],
      livestream: !!metadata["was_live"],
      duration_seconds: metadata["duration"] && round(metadata["duration"])
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

    if thumbnail_filepath do
      # NOTE: whole ordeal needed due to a bug I found in yt-dlp
      # https://github.com/yt-dlp/yt-dlp/issues/9445
      # Can be reverted to remove this entire conditional once fixed
      filepath =
        thumbnail_filepath
        |> String.split(~r{\.}, include_captures: true)
        |> List.insert_at(-3, "-thumb")
        |> Enum.join()

      %{
        thumbnail_filepath: filepath_if_exists(filepath)
      }
    else
      %{
        thumbnail_filepath: nil
      }
    end
  end

  defp parse_infojson_metadata(metadata) do
    %{
      metadata_filepath: filepath_if_exists(metadata["infojson_filename"])
    }
  end

  # NOTE: this should not be needed, but it is due to a bug in yt-dlp.
  # Can remove once this is resolved:
  # https://github.com/yt-dlp/yt-dlp/issues/9445#issuecomment-2018724344
  defp filepath_if_exists(nil), do: nil

  defp filepath_if_exists(filepath) do
    if File.exists?(filepath) do
      filepath
    else
      nil
    end
  end
end
