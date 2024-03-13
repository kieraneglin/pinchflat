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
end
