defmodule Pinchflat.Workers.FilesystemDataWorkerTest do
  use Pinchflat.DataCase

  import Pinchflat.MediaFixtures

  alias Pinchflat.Workers.FilesystemDataWorker

  describe "perform/1" do
    test "Computes and stores the media file size" do
      media_item = media_item_with_attachments()

      refute media_item.media_size_bytes

      perform_job(FilesystemDataWorker, %{id: media_item.id})

      assert Repo.reload!(media_item).media_size_bytes
    end
  end
end
