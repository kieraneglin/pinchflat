defmodule Pinchflat.SlowIndexing.MediaCollectionIndexingWorkerTest do
  use Pinchflat.DataCase

  import Mox
  import Pinchflat.TasksFixtures
  import Pinchflat.MediaFixtures
  import Pinchflat.SourcesFixtures

  alias Pinchflat.Tasks
  alias Pinchflat.Settings
  alias Pinchflat.Sources.Source
  alias Pinchflat.FastIndexing.FastIndexingWorker
  alias Pinchflat.Downloading.MediaDownloadWorker
  alias Pinchflat.SlowIndexing.MediaCollectionIndexingWorker

  setup :verify_on_exit!

  describe "kickoff_with_task/3" do
    setup do
      source = source_fixture(index_frequency_minutes: 10)

      {:ok, %{source: source}}
    end

    test "starts the worker", %{source: source} do
      assert [] = all_enqueued(worker: MediaCollectionIndexingWorker)
      assert {:ok, _} = MediaCollectionIndexingWorker.kickoff_with_task(source)
      assert [_] = all_enqueued(worker: MediaCollectionIndexingWorker)
    end

    test "attaches a task", %{source: source} do
      assert {:ok, task} = MediaCollectionIndexingWorker.kickoff_with_task(source)
      assert task.source_id == source.id
    end

    test "can be called with additional job arguments", %{source: source} do
      job_args = %{"force" => true}

      assert {:ok, _} = MediaCollectionIndexingWorker.kickoff_with_task(source, job_args)

      assert_enqueued(worker: MediaCollectionIndexingWorker, args: %{"id" => source.id, "force" => true})
    end

    test "can be called with additional job options", %{source: source} do
      job_opts = [max_attempts: 5]

      assert {:ok, _} = MediaCollectionIndexingWorker.kickoff_with_task(source, %{}, job_opts)

      [job] = all_enqueued(worker: MediaCollectionIndexingWorker, args: %{"id" => source.id})
      assert job.max_attempts == 5
    end
  end

  describe "perform/1" do
    setup do
      stub(AppriseRunnerMock, :run, fn _, _ -> {:ok, ""} end)

      :ok
    end

    test "it indexes the source if it should be indexed" do
      expect(YtDlpRunnerMock, :run, fn _url, _opts, _ot, _addl_opts -> {:ok, ""} end)

      source = source_fixture(index_frequency_minutes: 10)

      perform_job(MediaCollectionIndexingWorker, %{id: source.id})
    end

    test "it indexes the source no matter what if the source has never been indexed before" do
      expect(YtDlpRunnerMock, :run, fn _url, _opts, _ot, _addl_opts -> {:ok, ""} end)

      source = source_fixture(index_frequency_minutes: 0, last_indexed_at: nil)

      perform_job(MediaCollectionIndexingWorker, %{id: source.id})
    end

    test "it indexes the source no matter what if the 'force' arg is passed" do
      expect(YtDlpRunnerMock, :run, fn _url, _opts, _ot, _addl_opts -> {:ok, ""} end)

      source = source_fixture(index_frequency_minutes: 0, last_indexed_at: DateTime.utc_now())

      perform_job(MediaCollectionIndexingWorker, %{id: source.id, force: true})
    end

    test "it does not do any indexing if the source has been indexed and shouldn't be rescheduled" do
      expect(YtDlpRunnerMock, :run, 0, fn _url, _opts, _ot, _addl_opts -> {:ok, ""} end)

      source = source_fixture(index_frequency_minutes: -1, last_indexed_at: DateTime.utc_now())

      perform_job(MediaCollectionIndexingWorker, %{id: source.id})
    end

    test "it does not reschedule if the source shouldn't be indexed" do
      stub(YtDlpRunnerMock, :run, fn _url, _opts, _ot, _addl_opts -> {:ok, ""} end)

      source = source_fixture(index_frequency_minutes: -1)
      perform_job(MediaCollectionIndexingWorker, %{id: source.id})

      refute_enqueued(worker: MediaCollectionIndexingWorker, args: %{"id" => source.id})
    end

    test "it kicks off a download job for each pending media item" do
      expect(YtDlpRunnerMock, :run, fn _url, _opts, _ot, _addl_opts ->
        {:ok, source_attributes_return_fixture()}
      end)

      source = source_fixture(index_frequency_minutes: 10)
      perform_job(MediaCollectionIndexingWorker, %{id: source.id})

      assert length(all_enqueued(worker: MediaDownloadWorker)) == 3
    end

    test "it starts a job for any pending media item even if it's from another run" do
      expect(YtDlpRunnerMock, :run, fn _url, _opts, _ot, _addl_opts ->
        {:ok, source_attributes_return_fixture()}
      end)

      source = source_fixture(index_frequency_minutes: 10)
      media_item_fixture(%{source_id: source.id, media_filepath: nil})
      perform_job(MediaCollectionIndexingWorker, %{id: source.id})

      assert length(all_enqueued(worker: MediaDownloadWorker)) == 4
    end

    test "it does not kick off a job for media items that could not be saved" do
      expect(YtDlpRunnerMock, :run, fn _url, _opts, _ot, _addl_opts ->
        {:ok, source_attributes_return_fixture()}
      end)

      source = source_fixture(index_frequency_minutes: 10)
      media_item_fixture(%{source_id: source.id, media_filepath: nil, media_id: "video1"})
      perform_job(MediaCollectionIndexingWorker, %{id: source.id})

      # Only 3 jobs should be enqueued, since the first video is a duplicate
      assert length(all_enqueued(worker: MediaDownloadWorker))
    end

    test "it reschedules the job based on the index frequency" do
      expect(YtDlpRunnerMock, :run, fn _url, _opts, _ot, _addl_opts -> {:ok, ""} end)

      source = source_fixture(index_frequency_minutes: 10)
      perform_job(MediaCollectionIndexingWorker, %{id: source.id})

      assert_enqueued(
        worker: MediaCollectionIndexingWorker,
        args: %{"id" => source.id},
        scheduled_at: now_plus(source.index_frequency_minutes, :minutes)
      )
    end

    test "it creates a task for the rescheduled job" do
      expect(YtDlpRunnerMock, :run, fn _url, _opts, _ot, _addl_opts -> {:ok, ""} end)

      source = source_fixture(index_frequency_minutes: 10)

      task_count_fetcher = fn ->
        Enum.count(Tasks.list_tasks_for(source, "MediaCollectionIndexingWorker"))
      end

      assert_changed([from: 0, to: 1], task_count_fetcher, fn ->
        perform_job(MediaCollectionIndexingWorker, %{id: source.id})
      end)
    end

    test "it creates a future task for fast indexing if appropriate" do
      expect(YtDlpRunnerMock, :run, fn _url, _opts, _ot, _addl_opts -> {:ok, ""} end)

      source = source_fixture(index_frequency_minutes: 10, fast_index: true)
      perform_job(MediaCollectionIndexingWorker, %{id: source.id})

      assert_enqueued(
        worker: FastIndexingWorker,
        args: %{"id" => source.id},
        scheduled_at: now_plus(Source.fast_index_frequency(), :minutes)
      )
    end

    test "it deletes existing fast indexing tasks if a new one is created" do
      expect(YtDlpRunnerMock, :run, fn _url, _opts, _ot, _addl_opts -> {:ok, ""} end)

      source = source_fixture(index_frequency_minutes: 10, fast_index: true)
      {:ok, job} = Oban.insert(FastIndexingWorker.new(%{"id" => source.id}))
      task = task_fixture(source_id: source.id, job_id: job.id)

      perform_job(MediaCollectionIndexingWorker, %{id: source.id})

      assert_raise Ecto.NoResultsError, fn -> Repo.reload!(task) end
    end

    test "it does not create a task for fast indexing otherwise" do
      expect(YtDlpRunnerMock, :run, fn _url, _opts, _ot, _addl_opts -> {:ok, ""} end)

      source = source_fixture(index_frequency_minutes: 10, fast_index: false)
      perform_job(MediaCollectionIndexingWorker, %{id: source.id})

      refute_enqueued(worker: FastIndexingWorker)
    end

    test "it creates the basic media_item records" do
      expect(YtDlpRunnerMock, :run, fn _url, _opts, _ot, _addl_opts -> {:ok, source_attributes_return_fixture()} end)

      source = source_fixture(index_frequency_minutes: 10)

      media_item_fetcher = fn ->
        source
        |> Repo.preload(:media_items)
        |> Map.get(:media_items)
        |> Enum.map(fn media_item -> media_item.media_id end)
      end

      assert_changed([from: [], to: ["video1", "video2", "video3"]], media_item_fetcher, fn ->
        perform_job(MediaCollectionIndexingWorker, %{id: source.id})
      end)
    end

    test "does not blow up if the record doesn't exist" do
      assert :ok = perform_job(MediaCollectionIndexingWorker, %{id: 0})
    end
  end

  describe "perform/1 when testing apprise notifications" do
    setup do
      Settings.set(apprise_server: "server_1")

      :ok
    end

    test "sends a notification if new media was found" do
      source = source_fixture()

      expect(YtDlpRunnerMock, :run, fn _url, _opts, _ot, _addl_opts ->
        {:ok, source_attributes_return_fixture()}
      end)

      expect(AppriseRunnerMock, :run, fn servers, opts ->
        assert "server_1" = servers
        assert is_binary(Keyword.get(opts, :title))
        assert is_binary(Keyword.get(opts, :body))

        {:ok, ""}
      end)

      perform_job(MediaCollectionIndexingWorker, %{id: source.id})
    end
  end
end
