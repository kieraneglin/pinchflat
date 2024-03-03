defmodule Pinchflat.Tasks.MediaItemTasksTest do
  use Pinchflat.DataCase

  import Pinchflat.MediaFixtures

  alias Pinchflat.Tasks.MediaItemTasks

  describe "compute_and_save_media_filesize/1" do
    test "updates the media item with the file size" do
      media_item = media_item_with_attachments()

      refute media_item.media_size_bytes

      assert {:ok, media_item} = MediaItemTasks.compute_and_save_media_filesize(media_item)

      assert Repo.reload!(media_item).media_size_bytes
    end

    test "returns the error if operation fails" do
      media_item = media_item_fixture(%{media_filepath: "/nonexistent/file.mkv"})

      assert {:error, _} = MediaItemTasks.compute_and_save_media_filesize(media_item)
    end
  end
end
