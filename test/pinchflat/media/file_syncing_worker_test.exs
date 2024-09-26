defmodule Pinchflat.Media.FileSyncingWorkerTest do
  use Pinchflat.DataCase

  import Pinchflat.MediaFixtures
  import Pinchflat.SourcesFixtures

  alias Pinchflat.Media.FileSyncingWorker

  describe "kickoff_with_task/3" do
    test "starts the worker" do
      source = source_fixture()

      assert [] = all_enqueued(worker: FileSyncingWorker)
      assert {:ok, _} = FileSyncingWorker.kickoff_with_task(source)
      assert [_] = all_enqueued(worker: FileSyncingWorker)
    end

    test "attaches a task" do
      source = source_fixture()

      assert {:ok, task} = FileSyncingWorker.kickoff_with_task(source)
      assert task.source_id == source.id
    end
  end

  describe "perform/1" do
    test "syncs file presence on disk" do
      source = source_fixture()
      media_item = media_item_fixture(%{media_filepath: "/tmp/missing.mp4", source_id: source.id})

      perform_job(FileSyncingWorker, %{"id" => source.id})
      updated_media_item = Repo.reload!(media_item)

      refute updated_media_item.media_filepath
    end
  end
end
