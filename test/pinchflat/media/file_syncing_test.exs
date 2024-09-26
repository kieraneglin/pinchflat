defmodule Pinchflat.Media.FileSyncingTest do
  use Pinchflat.DataCase

  import Pinchflat.MediaFixtures

  alias Pinchflat.Media.FileSyncing

  describe "delete_outdated_files/2" do
    test "deletes outdated non-subtitle files" do
      new_media_item = media_item_with_attachments()
      old_media_item = media_item_with_attachments()

      assert :ok = FileSyncing.delete_outdated_files(old_media_item, new_media_item)

      assert File.exists?(new_media_item.media_filepath)
      refute File.exists?(old_media_item.media_filepath)
    end

    test "doesn't delete non-subtitle files if the new file is the same" do
      new_media_item = media_item_with_attachments()
      old_media_item = media_item_fixture(%{media_filepath: new_media_item.media_filepath})

      assert :ok = FileSyncing.delete_outdated_files(old_media_item, new_media_item)

      assert File.exists?(new_media_item.media_filepath)
      assert File.exists?(old_media_item.media_filepath)
    end

    test "doesn't delete the old file if the new file is missing that key" do
      new_media_item = media_item_fixture(%{media_filepath: nil})
      old_media_item = media_item_with_attachments()

      assert :ok = FileSyncing.delete_outdated_files(old_media_item, new_media_item)

      assert File.exists?(old_media_item.media_filepath)
    end

    test "deletes outdated subtitle files" do
      new_media_item = media_item_with_attachments()
      old_media_item = media_item_with_attachments()

      assert :ok = FileSyncing.delete_outdated_files(old_media_item, new_media_item)

      assert File.exists?(get_subtitle_filepath(new_media_item, "en"))
      refute File.exists?(get_subtitle_filepath(old_media_item, "en"))
    end

    test "keeps old subtitle files if the new file is the same" do
      new_media_item = media_item_with_attachments()
      old_media_item = media_item_fixture(%{subtitle_filepaths: new_media_item.subtitle_filepaths})

      assert :ok = FileSyncing.delete_outdated_files(old_media_item, new_media_item)

      assert File.exists?(get_subtitle_filepath(new_media_item, "en"))
      assert File.exists?(get_subtitle_filepath(old_media_item, "en"))
    end

    test "doesn't delete old subtitle files if the new file is missing that key" do
      new_media_item = media_item_fixture(%{subtitle_filepaths: []})
      old_media_item = media_item_with_attachments()

      assert :ok = FileSyncing.delete_outdated_files(old_media_item, new_media_item)

      assert File.exists?(get_subtitle_filepath(old_media_item, "en"))
    end
  end

  describe "sync_file_presence_on_disk/1" do
    test "removes attributes whose files are missing" do
      media_item = media_item_fixture(%{media_filepath: "/tmp/missing_file.mp4"})

      assert media_item.media_filepath
      assert [updated_media_item] = FileSyncing.sync_file_presence_on_disk([media_item])
      refute updated_media_item.media_filepath
    end

    test "doesn't remove attributes where the files still exist" do
      media_item = media_item_with_attachments()

      assert media_item.media_filepath
      assert [updated_media_item] = FileSyncing.sync_file_presence_on_disk([media_item])
      assert updated_media_item.media_filepath
    end

    test "removes subtitle files that are missing" do
      media_item = media_item_fixture(%{subtitle_filepaths: [["en", "/tmp/missing_file.srt"]]})

      assert get_subtitle_filepath(media_item, "en")
      assert [updated_media_item] = FileSyncing.sync_file_presence_on_disk([media_item])
      refute get_subtitle_filepath(updated_media_item, "en")
    end

    test "doesn't remove subtitle files that still exist" do
      media_item = media_item_with_attachments()

      assert get_subtitle_filepath(media_item, "en")
      assert [updated_media_item] = FileSyncing.sync_file_presence_on_disk([media_item])
      assert get_subtitle_filepath(updated_media_item, "en")
    end
  end

  defp get_subtitle_filepath(media_item, language) do
    Enum.reduce_while(media_item.subtitle_filepaths, nil, fn [lang, filepath], acc ->
      if lang == language do
        {:halt, filepath}
      else
        {:cont, acc}
      end
    end)
  end
end
