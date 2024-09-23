defmodule Pinchflat.Media.FileDeletion do
  @moduledoc """
  Functions for deleting files that are no longer needed by media items.
  """

  alias Pinchflat.Utils.MapUtils
  alias Pinchflat.Media.MediaItem
  alias Pinchflat.Utils.FilesystemUtils, as: FSUtils

  @doc """
  Deletes files that are no longer needed by a media item.

  This means that if a media item has been updated, the old and new versions
  can be passed and any files that are no longer needed will be deleted.

  An example is a video that gets its quality upgraded and its name changes
  between original download and re-download. The old file will exist on-disk
  with the old name but the database entry will point to the new file. This
  function can be used to delete the old file in this case.

  Returns :ok
  """
  def delete_outdated_files(old_media_item, new_media_item) do
    non_subtitle_keys = MediaItem.filepath_attributes() -- [:subtitle_filepaths]

    old_non_subtitles = Map.take(old_media_item, non_subtitle_keys)
    old_subtitles = MapUtils.from_nested_list(old_media_item.subtitle_filepaths)
    new_non_subtitles = Map.take(new_media_item, non_subtitle_keys)
    new_subtitles = MapUtils.from_nested_list(new_media_item.subtitle_filepaths)

    handle_file_deletion(old_non_subtitles, new_non_subtitles)
    handle_file_deletion(old_subtitles, new_subtitles)

    :ok
  end

  defp handle_file_deletion(old_attributes, new_attributes) do
    # The logic:
    #   - A file should only be deleted if it exists and the new file is different
    #   - The new attributes are the ones we're interested in keeping
    #   - If the old attributes have a key that doesn't exist in the new attributes, don't touch it.
    #     This is good for archiving but may be unpopular for other users so this may change.

    Enum.each(new_attributes, fn {key, new_filepath} ->
      old_filepath = Map.get(old_attributes, key)
      files_do_exist = old_filepath && new_filepath && File.exists?(old_filepath) && File.exists?(new_filepath)
      filepaths_are_different = old_filepath != new_filepath

      if files_do_exist && filepaths_are_different &&
           !FSUtils.filepaths_reference_same_file?(old_filepath, new_filepath) do
        FSUtils.delete_file_and_remove_empty_directories(old_filepath)
      end
    end)
  end
end
