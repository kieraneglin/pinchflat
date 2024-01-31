defmodule Pinchflat.Tasks.ChannelTasksTest do
  use Pinchflat.DataCase

  import Pinchflat.TasksFixtures
  import Pinchflat.MediaSourceFixtures

  alias Pinchflat.Tasks.Task
  alias Pinchflat.Tasks.ChannelTasks
  alias Pinchflat.Workers.MediaIndexingWorker

  describe "kickoff_indexing_task/1" do
    test "it does not schedule a job if the interval is <= 0" do
      channel = channel_fixture(index_frequency_minutes: -1)

      assert {:ok, :should_not_index} = ChannelTasks.kickoff_indexing_task(channel)

      refute_enqueued(worker: MediaIndexingWorker, args: %{"id" => channel.id})
    end

    test "it schedules a job if the interval is > 0" do
      channel = channel_fixture(index_frequency_minutes: 1)

      assert {:ok, _} = ChannelTasks.kickoff_indexing_task(channel)

      assert_enqueued(worker: MediaIndexingWorker, args: %{"id" => channel.id})
    end

    test "it creates and attaches a task if the interval is > 0" do
      channel = channel_fixture(index_frequency_minutes: 1)

      assert {:ok, %Task{} = task} = ChannelTasks.kickoff_indexing_task(channel)

      assert task.channel_id == channel.id
    end

    test "it deletes any pending tasks for the channel" do
      channel = channel_fixture()
      task = task_fixture(channel_id: channel.id)

      assert {:ok, _} = ChannelTasks.kickoff_indexing_task(channel)

      assert_raise Ecto.NoResultsError, fn -> Repo.reload!(task) end
    end
  end
end
