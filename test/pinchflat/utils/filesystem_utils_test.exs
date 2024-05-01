defmodule Pinchflat.Utils.FilesystemUtilsTest do
  use Pinchflat.DataCase

  import Pinchflat.MediaFixtures

  alias Pinchflat.Utils.FilesystemUtils

  describe "exists_and_nonempty?" do
    test "returns true if a file exists and has contents" do
      filepath = FilesystemUtils.generate_metadata_tmpfile(:json)
      File.write(filepath, "{}")

      assert FilesystemUtils.exists_and_nonempty?(filepath)

      File.rm!(filepath)
    end

    test "returns false if a file doesn't exist" do
      refute FilesystemUtils.exists_and_nonempty?("/nonexistent/file.json")
    end

    test "returns false if a file exists but is empty" do
      filepath = FilesystemUtils.generate_metadata_tmpfile(:json)

      refute FilesystemUtils.exists_and_nonempty?(filepath)

      File.rm!(filepath)
    end

    test "trims the contents before checking" do
      filepath = FilesystemUtils.generate_metadata_tmpfile(:json)
      File.write(filepath, "  \n\n  \r\n  ")

      refute FilesystemUtils.exists_and_nonempty?(filepath)

      File.rm!(filepath)
    end
  end

  describe "generate_metadata_tmpfile/1" do
    test "creates a tmpfile and returns its path" do
      res = FilesystemUtils.generate_metadata_tmpfile(:json)

      assert String.ends_with?(res, ".json")
      assert File.exists?(res)

      File.rm!(res)
    end
  end

  describe "compute_and_save_media_filesize/1" do
    test "updates the media item with the file size" do
      media_item = media_item_with_attachments()

      refute media_item.media_size_bytes

      assert {:ok, media_item} = FilesystemUtils.compute_and_save_media_filesize(media_item)

      assert Repo.reload!(media_item).media_size_bytes
    end

    test "returns the error if operation fails" do
      media_item = media_item_fixture(%{media_filepath: "/nonexistent/file.mkv"})

      assert {:error, _} = FilesystemUtils.compute_and_save_media_filesize(media_item)
    end
  end

  describe "write_p/3" do
    test "writes content to a file" do
      filepath = FilesystemUtils.generate_metadata_tmpfile(:json)
      content = "{}"

      assert :ok = FilesystemUtils.write_p(filepath, content)
      assert File.read!(filepath) == content

      File.rm!(filepath)
    end

    test "creates directories as needed" do
      tmpfile_directory = Application.get_env(:pinchflat, :tmpfile_directory)
      filepath = Path.join([tmpfile_directory, "foo", "bar", "file.json"])
      content = "{}"

      assert :ok = FilesystemUtils.write_p(filepath, content)
      assert File.read!(filepath) == content

      File.rm!(filepath)
    end
  end

  describe "write_p!/3" do
    test "writes content to a file" do
      filepath = FilesystemUtils.generate_metadata_tmpfile(:json)
      content = "{}"

      assert :ok = FilesystemUtils.write_p!(filepath, content)
      assert File.read!(filepath) == content

      File.rm!(filepath)
    end

    test "creates directories as needed" do
      tmpfile_directory = Application.get_env(:pinchflat, :tmpfile_directory)
      filepath = Path.join([tmpfile_directory, "foo", "bar", "file.json"])
      content = "{}"

      assert :ok = FilesystemUtils.write_p!(filepath, content)
      assert File.read!(filepath) == content

      File.rm!(filepath)
    end
  end

  describe "delete_file_and_remove_empty_directories/1" do
    test "deletes file at the provided filepath" do
      filepath = FilesystemUtils.generate_metadata_tmpfile(:json)

      assert File.exists?(filepath)

      assert :ok = FilesystemUtils.delete_file_and_remove_empty_directories(filepath)

      refute File.exists?(filepath)
    end

    test "deletes empty directories" do
      tmpfile_directory = Application.get_env(:pinchflat, :tmpfile_directory)
      filepath = Path.join([tmpfile_directory, "foo", "bar", "baz", "qux.json"])
      FilesystemUtils.write_p!(filepath, "")

      assert :ok = FilesystemUtils.delete_file_and_remove_empty_directories(filepath)

      refute File.exists?(filepath)
      refute File.exists?(Path.join([tmpfile_directory, "foo", "bar", "baz"]))
      refute File.exists?(Path.join([tmpfile_directory, "foo", "bar"]))
      refute File.exists?(Path.join([tmpfile_directory, "foo"]))
    end

    test "does not delete directories with other files in them" do
      tmpfile_directory = Application.get_env(:pinchflat, :tmpfile_directory)
      filepath_1 = Path.join([tmpfile_directory, "foo", "bar", "baz", "qux.json"])
      filepath_2 = Path.join([tmpfile_directory, "foo", "baz.json"])
      FilesystemUtils.write_p!(filepath_1, "")
      FilesystemUtils.write_p!(filepath_2, "")

      assert :ok = FilesystemUtils.delete_file_and_remove_empty_directories(filepath_1)

      refute File.exists?(filepath_1)
      refute File.exists?(Path.join([tmpfile_directory, "foo", "bar", "baz"]))
      refute File.exists?(Path.join([tmpfile_directory, "foo", "bar"]))

      assert File.exists?(filepath_2)
      assert File.exists?(Path.join([tmpfile_directory, "foo"]))

      # cleanup
      FilesystemUtils.delete_file_and_remove_empty_directories(filepath_2)
    end

    test "returns an error if file could not be deleted" do
      filepath = "/nonexistent/file.json"

      assert {:error, _} = FilesystemUtils.delete_file_and_remove_empty_directories(filepath)
    end
  end

  describe "cp_p!/2" do
    test "copies a file from source to destination" do
      source = "#{tmpfile_directory()}/source.json"
      FilesystemUtils.write_p!(source, "TEST")
      destination = "#{tmpfile_directory()}/destination.json"

      refute File.exists?(destination)
      FilesystemUtils.cp_p!(source, destination)
      assert File.exists?(destination)
      assert File.read!(destination) == "TEST"

      File.rm!(source)
      File.rm!(destination)
    end

    test "creates directories as needed" do
      source = "#{tmpfile_directory()}/source.json"
      FilesystemUtils.write_p!(source, "TEST")
      destination = "#{tmpfile_directory()}/foo/bar/destination.json"

      refute File.exists?(destination)
      FilesystemUtils.cp_p!(source, destination)
      assert File.exists?(destination)

      File.rm!(source)
      File.rm!(destination)
    end
  end

  defp tmpfile_directory do
    Application.get_env(:pinchflat, :tmpfile_directory)
  end
end
