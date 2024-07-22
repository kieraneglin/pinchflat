defmodule Pinchflat.Metadata.SourceImageParser do
  @moduledoc """
  Functions for parsing and storing source images.
  """
  alias Pinchflat.Utils.FilesystemUtils

  @doc """
  Given a base directory and source metadata, look for the appropriate images
  and move them to the base directory. Returns a map of image types and their
  filepaths (specifically for a source). If a given image type is not found,
  the key will not be present in the map.

  The metadata is expected to contain the `filepath` key for images, implying
  that the images have already been downloaded by yt-dlp. This method will NOT
  download images from the internet - it just copys them around.

  Returns a map with the possible keys :poster_filepath, :fanart_filepath, and
  :banner_filepath.
  """
  def store_source_images(base_directory, source_metadata) do
    (source_metadata["thumbnails"] || [])
    |> Enum.filter(&(&1["filepath"] != nil))
    |> select_useful_images(source_metadata)
    |> Enum.map(&move_image(&1, base_directory))
    |> Enum.into(%{})
  end

  defp select_useful_images(images, source_metadata) do
    labelled_images =
      Enum.reduce(images, %{}, fn image_map, acc ->
        case image_map do
          %{"id" => "avatar_uncropped"} -> put_image_key(acc, :poster, image_map["filepath"])
          %{"id" => "banner_uncropped"} -> put_image_key(acc, :fanart, image_map["filepath"])
          _ -> acc
        end
      end)

    labelled_images
    |> add_fallback_poster(source_metadata)
    |> put_image_key(:banner, determine_best_banner(images))
    |> Enum.filter(fn {_key, attrs} -> attrs.current_filepath end)
  end

  # If a poster is set, short-circuit and return the images as-is
  defp add_fallback_poster(%{poster: _} = images, _), do: images

  # If a poster is NOT set, see if we can find a suitable image to use as a fallback
  defp add_fallback_poster(images, source_metadata) do
    case source_metadata["entries"] do
      nil -> images
      [] -> images
      [first_entry | _] -> add_poster_from_entry_thumbnail(images, first_entry)
    end
  end

  defp add_poster_from_entry_thumbnail(images, entry) do
    thumbnail =
      (entry["thumbnails"] || [])
      |> Enum.reverse()
      |> Enum.find(& &1["filepath"])

    case thumbnail do
      nil -> images
      _ -> put_image_key(images, :poster, thumbnail["filepath"])
    end
  end

  defp determine_best_banner(images) do
    best_candidate =
      images
      # Filter out images that don't have a width and height attribute
      |> Enum.filter(&(&1["width"] && &1["height"]))
      # Sort images with the highest width first
      |> Enum.sort(&(&1["width"] >= &2["width"]))
      # Find the first image where the ratio of width to height is greater than 3
      |> Enum.find(&(&1["width"] / &1["height"] > 3))

    Map.get(best_candidate || %{}, "filepath")
  end

  defp move_image({_key, attrs}, base_directory) do
    extension = Path.extname(attrs.current_filepath)
    final_filepath = Path.join([base_directory, "#{attrs.final_filename}#{extension}"])

    FilesystemUtils.cp_p!(attrs.current_filepath, final_filepath)

    {attrs.attribute_name, final_filepath}
  end

  defp put_image_key(map, key, image) do
    attribute_atom = String.to_existing_atom("#{key}_filepath")

    Map.put(map, key, %{
      attribute_name: attribute_atom,
      final_filename: to_string(key),
      current_filepath: image
    })
  end
end
