defmodule Pinchflat.Workers.MediaIndexingWorkerTest do
  use Pinchflat.DataCase

  import Mox
  import Pinchflat.MediaSourceFixtures

  alias Pinchflat.Workers.MediaIndexingWorker

  setup :verify_on_exit!

  describe "perform/1" do
    test "it does not do any indexing if the channel shouldn't be indexed" do
      expect(YtDlpRunnerMock, :run, 0, fn _url, _opts -> {:ok, ""} end)

      channel = channel_fixture(index_frequency_minutes: -1)

      perform_job(MediaIndexingWorker, %{id: channel.id})
    end

    test "it does not reschedule if the channel shouldn't be indexed" do
      expect(YtDlpRunnerMock, :run, 0, fn _url, _opts -> {:ok, ""} end)

      channel = channel_fixture(index_frequency_minutes: -1)
      perform_job(MediaIndexingWorker, %{id: channel.id})

      refute_enqueued(worker: MediaIndexingWorker, args: %{"id" => channel.id})
    end

    test "it indexes the channel if it should be indexed" do
      expect(YtDlpRunnerMock, :run, 1, fn _url, _opts -> {:ok, ""} end)

      channel = channel_fixture(index_frequency_minutes: 10)

      perform_job(MediaIndexingWorker, %{id: channel.id})
    end

    test "it reschedules the job based on the index frequency" do
      expect(YtDlpRunnerMock, :run, 1, fn _url, _opts -> {:ok, ""} end)

      channel = channel_fixture(index_frequency_minutes: 10)
      perform_job(MediaIndexingWorker, %{id: channel.id})

      assert_enqueued(
        worker: MediaIndexingWorker,
        args: %{"id" => channel.id},
        scheduled_at: now_plus(channel.index_frequency_minutes, :minutes)
      )
    end

    test "it creates the basic media_item records" do
      expect(YtDlpRunnerMock, :run, 1, fn _url, _opts -> {:ok, "video1\nvideo2"} end)

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
