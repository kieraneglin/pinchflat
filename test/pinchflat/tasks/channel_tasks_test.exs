defmodule Pinchflat.Tasks.ChannelTasksTest do
  use Pinchflat.DataCase

  import Pinchflat.MediaSourceFixtures

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
  end
end
