defmodule Pinchflat.Tasks.SourceTasksTest do
  use Pinchflat.DataCase

  import Pinchflat.TasksFixtures
  import Pinchflat.MediaFixtures
  import Pinchflat.MediaSourceFixtures

  alias Pinchflat.Tasks
  alias Pinchflat.Tasks.Task
  alias Pinchflat.Tasks.SourceTasks
  alias Pinchflat.Workers.MediaIndexingWorker
  alias Pinchflat.Workers.VideoDownloadWorker

  describe "kickoff_indexing_task/1" do
    test "it does not schedule a job if the interval is <= 0" do
      source = source_fixture(index_frequency_minutes: -1)

      assert {:ok, :should_not_index} = SourceTasks.kickoff_indexing_task(source)

      refute_enqueued(worker: MediaIndexingWorker, args: %{"id" => source.id})
    end

    test "it schedules a job if the interval is > 0" do
      source = source_fixture(index_frequency_minutes: 1)

      assert {:ok, _} = SourceTasks.kickoff_indexing_task(source)

      assert_enqueued(worker: MediaIndexingWorker, args: %{"id" => source.id})
    end

    test "it creates and attaches a task if the interval is > 0" do
      source = source_fixture(index_frequency_minutes: 1)

      assert {:ok, %Task{} = task} = SourceTasks.kickoff_indexing_task(source)

      assert task.source_id == source.id
    end

    test "it deletes any pending tasks for the source" do
      source = source_fixture()
      task = task_fixture(source_id: source.id)

      assert {:ok, _} = SourceTasks.kickoff_indexing_task(source)

      assert_raise Ecto.NoResultsError, fn -> Repo.reload!(task) end
    end
  end

  describe "enqueue_pending_media_downloads/1" do
    test "it enqueues a job for each pending media item" do
      source = source_fixture()
      media_item = media_item_fixture(source_id: source.id, media_filepath: nil)

      assert :ok = SourceTasks.enqueue_pending_media_downloads(source)

      assert_enqueued(worker: VideoDownloadWorker, args: %{"id" => media_item.id})
    end

    test "it does not enqueue a job for media items with a filepath" do
      source = source_fixture()
      _media_item = media_item_fixture(source_id: source.id, media_filepath: "some/filepath.mp4")

      assert :ok = SourceTasks.enqueue_pending_media_downloads(source)

      refute_enqueued(worker: VideoDownloadWorker)
    end

    test "it attaches a task to each enqueued job" do
      source = source_fixture()
      media_item = media_item_fixture(source_id: source.id, media_filepath: nil)

      assert [] = Tasks.list_tasks_for(:media_item_id, media_item.id)

      assert :ok = SourceTasks.enqueue_pending_media_downloads(source)

      assert [_] = Tasks.list_tasks_for(:media_item_id, media_item.id)
    end
  end
end
