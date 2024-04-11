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
    |> select_useful_images()
    |> Enum.map(&move_image(&1, base_directory))
    |> Enum.into(%{})
  end

  defp select_useful_images(images) do
    labelled_images =
      Enum.reduce(images, [], fn image_map, acc ->
        case image_map do
          %{"id" => "avatar_uncropped"} ->
            acc ++ [{:poster, :poster_filepath, image_map["filepath"]}]

          %{"id" => "banner_uncropped"} ->
            acc ++ [{:fanart, :fanart_filepath, image_map["filepath"]}]

          _ ->
            acc
        end
      end)

    labelled_images
    |> Enum.concat([{:banner, :banner_filepath, determine_best_banner(images)}])
    |> Enum.filter(fn {_, _, tmp_filepath} -> tmp_filepath end)
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

  defp move_image({filename, source_attr_name, tmp_filepath}, base_directory) do
    extension = Path.extname(tmp_filepath)
    final_filepath = Path.join([base_directory, "#{filename}#{extension}"])

    FilesystemUtils.cp_p!(tmp_filepath, final_filepath)

    {source_attr_name, final_filepath}
  end
end
