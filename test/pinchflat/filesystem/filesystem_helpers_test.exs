defmodule Pinchflat.Filesystem.FilesystemHelpersTest do
  use Pinchflat.DataCase

  import Pinchflat.MediaFixtures

  alias Pinchflat.Filesystem.FilesystemHelpers

  describe "generate_metadata_tmpfile/1" do
    test "creates a tmpfile and returns its path" do
      res = FilesystemHelpers.generate_metadata_tmpfile(:json)

      assert String.ends_with?(res, ".json")
      assert File.exists?(res)

      File.rm!(res)
    end
  end

  describe "compute_and_save_media_filesize/1" do
    test "updates the media item with the file size" do
      media_item = media_item_with_attachments()

      refute media_item.media_size_bytes

      assert {:ok, media_item} = FilesystemHelpers.compute_and_save_media_filesize(media_item)

      assert Repo.reload!(media_item).media_size_bytes
    end

    test "returns the error if operation fails" do
      media_item = media_item_fixture(%{media_filepath: "/nonexistent/file.mkv"})

      assert {:error, _} = FilesystemHelpers.compute_and_save_media_filesize(media_item)
    end
  end

  describe "write_p!/3" do
    test "writes content to a file" do
      filepath = FilesystemHelpers.generate_metadata_tmpfile(:json)
      content = "{}"

      assert :ok = FilesystemHelpers.write_p!(filepath, content)
      assert File.read!(filepath) == content

      File.rm!(filepath)
    end

    test "creates directories as needed" do
      tmpfile_directory = Application.get_env(:pinchflat, :tmpfile_directory)
      filepath = Path.join([tmpfile_directory, "foo", "bar", "file.json"])
      content = "{}"

      assert :ok = FilesystemHelpers.write_p!(filepath, content)
      assert File.read!(filepath) == content

      File.rm!(filepath)
    end
  end

  describe "delete_file_and_remove_empty_directories/1" do
    test "deletes file at the provided filepath" do
      filepath = FilesystemHelpers.generate_metadata_tmpfile(:json)

      assert File.exists?(filepath)

      assert :ok = FilesystemHelpers.delete_file_and_remove_empty_directories(filepath)

      refute File.exists?(filepath)
    end

    test "deletes empty directories" do
      tmpfile_directory = Application.get_env(:pinchflat, :tmpfile_directory)
      filepath = Path.join([tmpfile_directory, "foo", "bar", "baz", "qux.json"])
      FilesystemHelpers.write_p!(filepath, "")

      assert :ok = FilesystemHelpers.delete_file_and_remove_empty_directories(filepath)

      refute File.exists?(filepath)
      refute File.exists?(Path.join([tmpfile_directory, "foo", "bar", "baz"]))
      refute File.exists?(Path.join([tmpfile_directory, "foo", "bar"]))
      refute File.exists?(Path.join([tmpfile_directory, "foo"]))
    end

    test "does not delete directories with other files in them" do
      tmpfile_directory = Application.get_env(:pinchflat, :tmpfile_directory)
      filepath_1 = Path.join([tmpfile_directory, "foo", "bar", "baz", "qux.json"])
      filepath_2 = Path.join([tmpfile_directory, "foo", "baz.json"])
      FilesystemHelpers.write_p!(filepath_1, "")
      FilesystemHelpers.write_p!(filepath_2, "")

      assert :ok = FilesystemHelpers.delete_file_and_remove_empty_directories(filepath_1)

      refute File.exists?(filepath_1)
      refute File.exists?(Path.join([tmpfile_directory, "foo", "bar", "baz"]))
      refute File.exists?(Path.join([tmpfile_directory, "foo", "bar"]))

      assert File.exists?(filepath_2)
      assert File.exists?(Path.join([tmpfile_directory, "foo"]))

      # cleanup
      FilesystemHelpers.delete_file_and_remove_empty_directories(filepath_2)
    end

    test "returns an error if file could not be deleted" do
      filepath = "/nonexistent/file.json"

      assert {:error, _} = FilesystemHelpers.delete_file_and_remove_empty_directories(filepath)
    end
  end
end
