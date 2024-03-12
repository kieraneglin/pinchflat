defmodule Pinchflat.FastIndexing.FastIndexingHelpersTest do
  use Pinchflat.DataCase

  import Mox
  import Pinchflat.TasksFixtures
  import Pinchflat.MediaFixtures
  import Pinchflat.SourcesFixtures
  import Pinchflat.ProfilesFixtures

  alias Pinchflat.Tasks
  alias Pinchflat.Tasks.Task
  alias Pinchflat.Tasks.SourceTasks
  alias Pinchflat.Media.MediaItem
  alias Pinchflat.Downloading.MediaDownloadWorker
  alias Pinchflat.FastIndexing.MediaIndexingWorker
  alias Pinchflat.FastIndexing.FastIndexingHelpers
  alias Pinchflat.FastIndexing.FastIndexingWorker
  alias Pinchflat.SlowIndexing.MediaCollectionIndexingWorker

  setup :verify_on_exit!

  describe "kickoff_fast_indexing_task/1" do
    test "it schedules a job" do
      source = source_fixture()

      assert {:ok, _} = FastIndexingHelpers.kickoff_fast_indexing_task(source)

      assert_enqueued(worker: FastIndexingWorker, args: %{"id" => source.id})
    end

    test "it creates and attaches a task" do
      source = source_fixture()

      assert {:ok, %Task{} = task} = FastIndexingHelpers.kickoff_fast_indexing_task(source)

      assert task.source_id == source.id
    end

    test "it deletes any fast indexing tasks for the source" do
      source = source_fixture()
      {:ok, job} = Oban.insert(FastIndexingWorker.new(%{"id" => source.id}))
      task = task_fixture(source_id: source.id, job_id: job.id)

      assert {:ok, _} = FastIndexingHelpers.kickoff_fast_indexing_task(source)

      assert_raise Ecto.NoResultsError, fn -> Repo.reload!(task) end
    end
  end

  describe "kickoff_indexing_tasks_from_youtube_rss_feed/1" do
    setup do
      {:ok, [source: source_fixture()]}
    end

    test "enqueues a new worker for each new media_id in the source's RSS feed", %{source: source} do
      expect(HTTPClientMock, :get, fn _url -> {:ok, "<yt:videoId>test_1</yt:videoId>"} end)

      assert :ok = FastIndexingHelpers.kickoff_indexing_tasks_from_youtube_rss_feed(source)

      assert [worker] = all_enqueued(worker: MediaIndexingWorker)
      assert worker.args["id"] == source.id
      assert worker.args["media_url"] == "https://www.youtube.com/watch?v=test_1"
    end

    test "does not enqueue a new worker for the source's media IDs we already know about", %{source: source} do
      expect(HTTPClientMock, :get, fn _url -> {:ok, "<yt:videoId>test_1</yt:videoId>"} end)
      media_item_fixture(source_id: source.id, media_id: "test_1")

      assert :ok = FastIndexingHelpers.kickoff_indexing_tasks_from_youtube_rss_feed(source)

      refute_enqueued(worker: MediaIndexingWorker)
    end
  end
end
