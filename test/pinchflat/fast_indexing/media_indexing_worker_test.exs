defmodule Pinchflat.FastIndexing.MediaIndexingWorkerTest do
  use Pinchflat.DataCase

  import Mox
  import Pinchflat.MediaFixtures
  import Pinchflat.SourcesFixtures

  alias Pinchflat.Media.MediaItem
  alias Pinchflat.Downloading.MediaDownloadWorker
  alias Pinchflat.FastIndexing.MediaIndexingWorker

  @media_url "https://www.youtube.com/watch?v=1234567890"

  setup :verify_on_exit!

  setup do
    source = source_fixture()

    {:ok, source: source}
  end

  describe "kickoff_with_task/2" do
    test "starts the worker", %{source: source} do
      assert [] = all_enqueued(worker: MediaIndexingWorker)
      assert {:ok, _} = MediaIndexingWorker.kickoff_with_task(source, @media_url)
      assert [_] = all_enqueued(worker: MediaIndexingWorker)
    end

    test "attaches a task", %{source: source} do
      assert {:ok, task} = MediaIndexingWorker.kickoff_with_task(source, @media_url)
      assert task.source_id == source.id
    end
  end

  describe "perform/1" do
    test "indexes the media item and saves it to the database", %{source: source} do
      expect(YtDlpRunnerMock, :run, fn _url, _opts, _ot ->
        {:ok, media_attributes_return_fixture()}
      end)

      before = Repo.aggregate(MediaItem, :count, :id)
      perform_job(MediaIndexingWorker, %{id: source.id, media_url: @media_url})

      assert Repo.aggregate(MediaItem, :count, :id) == before + 1
    end

    test "enqueues a download job for the media item", %{source: source} do
      expect(YtDlpRunnerMock, :run, fn _url, _opts, _ot ->
        {:ok, media_attributes_return_fixture()}
      end)

      perform_job(MediaIndexingWorker, %{id: source.id, media_url: @media_url})

      assert [_] = all_enqueued(worker: MediaDownloadWorker)
    end

    test "does not blow up if the record doesn't exist" do
      assert :ok = perform_job(MediaDownloadWorker, %{id: 0, media_url: @media_url})
    end
  end
end
