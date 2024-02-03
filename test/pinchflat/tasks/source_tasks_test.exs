defmodule Pinchflat.Tasks.SourceTasksTest do
  use Pinchflat.DataCase

  import Pinchflat.TasksFixtures
  import Pinchflat.MediaSourceFixtures

  alias Pinchflat.Tasks.Task
  alias Pinchflat.Tasks.SourceTasks
  alias Pinchflat.Workers.MediaIndexingWorker

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
end
