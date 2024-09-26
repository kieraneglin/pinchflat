defmodule Pinchflat.Media.FileSyncing do
  @moduledoc """
  Functions for ensuring file state is accurately reflected in the database.
  """

  alias Pinchflat.Media
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

  @doc """
  Nillifies any media item filepaths that don't exist on disk for a list of media items

  returns [%MediaItem{}]
  """
  def sync_file_presence_on_disk(media_items) do
    Enum.map(media_items, fn media_item ->
      new_attributes = sync_media_item_files(media_item)
      # Doing this one-by-one instead of batching since this process
      # can take time and a batch could let MediaItem state get out of sync
      {:ok, updated_media_item} = Media.update_media_item(media_item, new_attributes)

      updated_media_item
    end)
  end

  defp handle_file_deletion(old_attributes, new_attributes) do
    # The logic:
    #   - A file should only be deleted if it exists and the new file is different
    #   - The new attributes are the ones we're interested in keeping
    #   - If the old attributes have a key that doesn't exist in the new attributes, don't touch it.
    #     This is good for archiving but may be unpopular for other users so this may change.

    Enum.each(new_attributes, fn {key, new_filepath} ->
      old_filepath = Map.get(old_attributes, key)
      files_have_changed = old_filepath && new_filepath && old_filepath != new_filepath
      files_exist_on_disk = files_have_changed && File.exists?(old_filepath) && File.exists?(new_filepath)

      if files_exist_on_disk && !FSUtils.filepaths_reference_same_file?(old_filepath, new_filepath) do
        FSUtils.delete_file_and_remove_empty_directories(old_filepath)
      end
    end)
  end

  defp sync_media_item_files(media_item) do
    non_subtitle_keys = MediaItem.filepath_attributes() -- [:subtitle_filepaths]
    subtitle_keys = MapUtils.from_nested_list(media_item.subtitle_filepaths)
    non_subtitles = Map.take(media_item, non_subtitle_keys)

    # This one is checking for the negative (ie: only update if the file doesn't exist)
    new_non_subtitle_attrs =
      Enum.reduce(non_subtitles, %{}, fn {key, filepath}, acc ->
        if filepath && File.exists?(filepath), do: acc, else: Map.put(acc, key, nil)
      end)

    # This one is checking for the positive (ie: only update if the file exists)
    # This is because subtitles, being an array type in the DB, are most easily updated
    # by a full replacement rather than finding the actual diff
    new_subtitle_attrs =
      Enum.reduce(subtitle_keys, [], fn {key, filepath}, acc ->
        if filepath && File.exists?(filepath), do: acc ++ [[key, filepath]], else: acc
      end)

    Map.put(new_non_subtitle_attrs, :subtitle_filepaths, new_subtitle_attrs)
  end
end
