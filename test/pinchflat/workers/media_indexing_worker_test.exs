defmodule Pinchflat.Workers.MediaIndexingWorkerTest do
  use Pinchflat.DataCase

  import Mox
  import Pinchflat.MediaFixtures
  import Pinchflat.MediaSourceFixtures

  alias Pinchflat.Tasks
  alias Pinchflat.Workers.MediaIndexingWorker
  alias Pinchflat.Workers.VideoDownloadWorker

  setup :verify_on_exit!

  describe "perform/1" do
    test "it does not do any indexing if the channel shouldn't be indexed" do
      expect(YtDlpRunnerMock, :run, 0, fn _url, _opts, _ot -> {:ok, ""} end)

      channel = channel_fixture(index_frequency_minutes: -1)

      perform_job(MediaIndexingWorker, %{id: channel.id})
    end

    test "it does not reschedule if the channel shouldn't be indexed" do
      expect(YtDlpRunnerMock, :run, 0, fn _url, _opts, _ot -> {:ok, ""} end)

      channel = channel_fixture(index_frequency_minutes: -1)
      perform_job(MediaIndexingWorker, %{id: channel.id})

      refute_enqueued(worker: MediaIndexingWorker, args: %{"id" => channel.id})
    end

    test "it indexes the channel if it should be indexed" do
      expect(YtDlpRunnerMock, :run, fn _url, _opts, _ot -> {:ok, ""} end)

      channel = channel_fixture(index_frequency_minutes: 10)

      perform_job(MediaIndexingWorker, %{id: channel.id})
    end

    test "it kicks off a download job for each pending media item" do
      expect(YtDlpRunnerMock, :run, fn _url, _opts, _ot -> {:ok, "video1"} end)

      channel = channel_fixture(index_frequency_minutes: 10)
      perform_job(MediaIndexingWorker, %{id: channel.id})

      assert [_] = all_enqueued(worker: VideoDownloadWorker)
    end

    test "it starts a job for any pending media item even if it's from another run" do
      expect(YtDlpRunnerMock, :run, fn _url, _opts, _ot -> {:ok, "video1"} end)

      channel = channel_fixture(index_frequency_minutes: 10)
      media_item_fixture(%{channel_id: channel.id, media_filepath: nil})
      perform_job(MediaIndexingWorker, %{id: channel.id})

      assert [_, _] = all_enqueued(worker: VideoDownloadWorker)
    end

    test "it does not kick off a job for media items that could not be saved" do
      expect(YtDlpRunnerMock, :run, fn _url, _opts, _ot -> {:ok, "video1\nvideo1"} end)

      channel = channel_fixture(index_frequency_minutes: 10)
      perform_job(MediaIndexingWorker, %{id: channel.id})

      # Only one job should be enqueued, since the second video is a duplicate
      assert [_] = all_enqueued(worker: VideoDownloadWorker)
    end

    test "it reschedules the job based on the index frequency" do
      expect(YtDlpRunnerMock, :run, fn _url, _opts, _ot -> {:ok, ""} end)

      channel = channel_fixture(index_frequency_minutes: 10)
      perform_job(MediaIndexingWorker, %{id: channel.id})

      assert_enqueued(
        worker: MediaIndexingWorker,
        args: %{"id" => channel.id},
        scheduled_at: now_plus(channel.index_frequency_minutes, :minutes)
      )
    end

    test "it creates a task for the rescheduled job" do
      expect(YtDlpRunnerMock, :run, fn _url, _opts, _ot -> {:ok, ""} end)

      channel = channel_fixture(index_frequency_minutes: 10)
      task_count_fetcher = fn -> Enum.count(Tasks.list_tasks()) end

      assert_changed([from: 0, to: 1], task_count_fetcher, fn ->
        perform_job(MediaIndexingWorker, %{id: channel.id})
      end)
    end

    test "it creates the basic media_item records" do
      expect(YtDlpRunnerMock, :run, fn _url, _opts, _ot -> {:ok, "video1\nvideo2"} end)

      channel = channel_fixture(index_frequency_minutes: 10)

      media_item_fetcher = fn ->
        channel
        |> Repo.preload(:media_items)
        |> Map.get(:media_items)
        |> Enum.map(fn media_item -> media_item.media_id end)
      end

      assert_changed([from: [], to: ["video1", "video2"]], media_item_fetcher, fn ->
        perform_job(MediaIndexingWorker, %{id: channel.id})
      end)
    end
  end
end
