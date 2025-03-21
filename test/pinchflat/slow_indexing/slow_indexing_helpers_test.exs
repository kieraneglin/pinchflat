defmodule Pinchflat.SlowIndexing.SlowIndexingHelpersTest do
  use Pinchflat.DataCase

  import Pinchflat.TasksFixtures
  import Pinchflat.MediaFixtures
  import Pinchflat.SourcesFixtures
  import Pinchflat.ProfilesFixtures

  alias Pinchflat.Tasks
  alias Pinchflat.Tasks.Task
  alias Pinchflat.Media.MediaItem
  alias Pinchflat.FastIndexing.FastIndexingWorker
  alias Pinchflat.Downloading.MediaDownloadWorker
  alias Pinchflat.SlowIndexing.SlowIndexingHelpers
  alias Pinchflat.SlowIndexing.MediaCollectionIndexingWorker

  setup do
    {:ok, %{source: source_fixture()}}
  end

  describe "kickoff_indexing_task/3" do
    test "schedules a job" do
      source = source_fixture(index_frequency_minutes: 1)

      assert {:ok, _} = SlowIndexingHelpers.kickoff_indexing_task(source)

      assert_enqueued(worker: MediaCollectionIndexingWorker, args: %{"id" => source.id})
    end

    test "schedules a job for the future based on when the source was last indexed" do
      source = source_fixture(index_frequency_minutes: 30, last_indexed_at: now_minus(5, :minutes))

      assert {:ok, _} = SlowIndexingHelpers.kickoff_indexing_task(source)

      [job] = all_enqueued(worker: MediaCollectionIndexingWorker, args: %{"id" => source.id})

      assert_in_delta DateTime.diff(job.scheduled_at, DateTime.utc_now(), :minute), 25, 1
    end

    test "schedules a job immediately if the source was indexed far in the past" do
      source = source_fixture(index_frequency_minutes: 30, last_indexed_at: now_minus(60, :minutes))

      assert {:ok, _} = SlowIndexingHelpers.kickoff_indexing_task(source)

      [job] = all_enqueued(worker: MediaCollectionIndexingWorker, args: %{"id" => source.id})

      assert_in_delta DateTime.diff(job.scheduled_at, DateTime.utc_now(), :second), 0, 1
    end

    test "schedules a job immediately if the source has never been indexed" do
      source = source_fixture(index_frequency_minutes: 30, last_indexed_at: nil)

      assert {:ok, _} = SlowIndexingHelpers.kickoff_indexing_task(source)

      [job] = all_enqueued(worker: MediaCollectionIndexingWorker, args: %{"id" => source.id})

      assert_in_delta DateTime.diff(job.scheduled_at, DateTime.utc_now(), :second), 0, 1
    end

    test "schedules a job immediately if the user is forcing an index" do
      source = source_fixture(index_frequency_minutes: 30, last_indexed_at: now_minus(5, :minutes))

      assert {:ok, _} = SlowIndexingHelpers.kickoff_indexing_task(source, %{force: true})

      [job] = all_enqueued(worker: MediaCollectionIndexingWorker, args: %{"id" => source.id})

      assert_in_delta DateTime.diff(job.scheduled_at, DateTime.utc_now(), :second), 0, 1
    end

    test "creates and attaches a task" do
      source = source_fixture(index_frequency_minutes: 1)

      assert {:ok, %Task{} = task} = SlowIndexingHelpers.kickoff_indexing_task(source)

      assert task.source_id == source.id
    end

    test "deletes any pending media collection tasks for the source" do
      source = source_fixture()
      {:ok, job} = Oban.insert(MediaCollectionIndexingWorker.new(%{"id" => source.id}))
      task = task_fixture(source_id: source.id, job_id: job.id)

      assert {:ok, _} = SlowIndexingHelpers.kickoff_indexing_task(source)

      assert_raise Ecto.NoResultsError, fn -> Repo.reload!(task) end
    end

    test "deletes any executing media collection tasks for the source" do
      source = source_fixture()
      {:ok, job} = Oban.insert(MediaCollectionIndexingWorker.new(%{"id" => source.id}))
      task = task_fixture(source_id: source.id, job_id: job.id)
      Repo.update_all(from(Oban.Job, where: [id: ^task.job_id], update: [set: [state: "executing"]]), [])

      assert {:ok, _} = SlowIndexingHelpers.kickoff_indexing_task(source)

      assert_raise Ecto.NoResultsError, fn -> Repo.reload!(task) end
    end

    test "can be called with additional job arguments" do
      source = source_fixture(index_frequency_minutes: 1)
      job_args = %{"force" => true}

      assert {:ok, _} = SlowIndexingHelpers.kickoff_indexing_task(source, job_args)

      assert_enqueued(worker: MediaCollectionIndexingWorker, args: %{"id" => source.id, "force" => true})
    end

    test "can be called with additional job options" do
      source = source_fixture(index_frequency_minutes: 1)
      job_opts = [max_attempts: 5]

      assert {:ok, _} = SlowIndexingHelpers.kickoff_indexing_task(source, %{}, job_opts)

      [job] = all_enqueued(worker: MediaCollectionIndexingWorker, args: %{"id" => source.id})
      assert job.max_attempts == 5
    end
  end

  describe "delete_indexing_tasks/2" do
    test "deletes slow indexing tasks for the source", %{source: source} do
      {:ok, job} = Oban.insert(MediaCollectionIndexingWorker.new(%{"id" => source.id}))
      _task = task_fixture(source_id: source.id, job_id: job.id)

      assert_enqueued(worker: MediaCollectionIndexingWorker, args: %{"id" => source.id})
      assert :ok = SlowIndexingHelpers.delete_indexing_tasks(source)
      refute_enqueued(worker: MediaCollectionIndexingWorker)
    end

    test "deletes fast indexing tasks for the source", %{source: source} do
      {:ok, job} = Oban.insert(FastIndexingWorker.new(%{"id" => source.id}))
      _task = task_fixture(source_id: source.id, job_id: job.id)

      assert_enqueued(worker: FastIndexingWorker, args: %{"id" => source.id})
      assert :ok = SlowIndexingHelpers.delete_indexing_tasks(source)
      refute_enqueued(worker: FastIndexingWorker)
    end

    test "doesn't normally delete currently executing tasks", %{source: source} do
      {:ok, job} = Oban.insert(MediaCollectionIndexingWorker.new(%{"id" => source.id}))
      task = task_fixture(source_id: source.id, job_id: job.id)

      from(Oban.Job, where: [id: ^job.id], update: [set: [state: "executing"]])
      |> Repo.update_all([])

      assert Repo.reload!(task)
      assert :ok = SlowIndexingHelpers.delete_indexing_tasks(source)
      assert Repo.reload!(task)
    end

    test "can optionally delete currently executing tasks", %{source: source} do
      {:ok, job} = Oban.insert(MediaCollectionIndexingWorker.new(%{"id" => source.id}))
      task = task_fixture(source_id: source.id, job_id: job.id)

      from(Oban.Job, where: [id: ^job.id], update: [set: [state: "executing"]])
      |> Repo.update_all([])

      assert Repo.reload!(task)
      assert :ok = SlowIndexingHelpers.delete_indexing_tasks(source, include_executing: true)
      assert_raise Ecto.NoResultsError, fn -> Repo.reload!(task) end
    end
  end

  describe "index_and_enqueue_download_for_media_items/2" do
    setup do
      stub(YtDlpRunnerMock, :run, fn _url, :get_media_attributes_for_collection, _opts, _ot, _addl_opts ->
        {:ok, source_attributes_return_fixture()}
      end)

      :ok
    end

    test "creates a media_item record for each media ID returned", %{source: source} do
      assert media_items = SlowIndexingHelpers.index_and_enqueue_download_for_media_items(source)

      assert Enum.count(media_items) == 3
      assert ["video1", "video2", "video3"] == Enum.map(media_items, & &1.media_id)
      assert ["Video 1", "Video 2", "Video 3"] == Enum.map(media_items, & &1.title)
      assert ["desc1", "desc2", "desc3"] == Enum.map(media_items, & &1.description)
      assert Enum.all?(media_items, fn mi -> mi.original_url end)
      assert Enum.all?(media_items, fn %MediaItem{} -> true end)
    end

    test "attaches all media_items to the given source", %{source: source} do
      source_id = source.id
      assert media_items = SlowIndexingHelpers.index_and_enqueue_download_for_media_items(source)

      assert Enum.count(media_items) == 3
      assert Enum.all?(media_items, fn %MediaItem{source_id: ^source_id} -> true end)
    end

    test "won't duplicate media_items based on media_id and source", %{source: source} do
      _first_run = SlowIndexingHelpers.index_and_enqueue_download_for_media_items(source)
      _duplicate_run = SlowIndexingHelpers.index_and_enqueue_download_for_media_items(source)

      media_items = Repo.preload(source, :media_items).media_items
      assert Enum.count(media_items) == 3
    end

    test "can duplicate media_ids for different sources", %{source: source} do
      other_source = source_fixture()

      media_items = SlowIndexingHelpers.index_and_enqueue_download_for_media_items(source)
      media_items_other_source = SlowIndexingHelpers.index_and_enqueue_download_for_media_items(other_source)

      assert Enum.count(media_items) == 3
      assert Enum.count(media_items_other_source) == 3

      assert Enum.map(media_items, & &1.media_id) ==
               Enum.map(media_items_other_source, & &1.media_id)
    end

    test "returns a list of media_items", %{source: source} do
      first_run = SlowIndexingHelpers.index_and_enqueue_download_for_media_items(source)
      duplicate_run = SlowIndexingHelpers.index_and_enqueue_download_for_media_items(source)

      first_ids = Enum.map(first_run, & &1.id)
      duplicate_ids = Enum.map(duplicate_run, & &1.id)

      assert first_ids == duplicate_ids
    end

    test "updates the source's last_indexed_at field", %{source: source} do
      assert source.last_indexed_at == nil

      SlowIndexingHelpers.index_and_enqueue_download_for_media_items(source)
      source = Repo.reload!(source)

      assert DateTime.diff(DateTime.utc_now(), source.last_indexed_at) < 2
    end

    test "enqueues a job for each pending media item" do
      source = source_fixture()
      media_item = media_item_fixture(source_id: source.id, media_filepath: nil)

      SlowIndexingHelpers.index_and_enqueue_download_for_media_items(source)

      assert_enqueued(worker: MediaDownloadWorker, args: %{"id" => media_item.id})
    end

    test "does not attach tasks if the source is set to not download" do
      source = source_fixture(download_media: false)
      media_item = media_item_fixture(source_id: source.id, media_filepath: nil)

      SlowIndexingHelpers.index_and_enqueue_download_for_media_items(source)

      assert [] = Tasks.list_tasks_for(media_item)
    end

    test "doesn't blow up if a media item cannot be coerced into a struct", %{source: source} do
      stub(YtDlpRunnerMock, :run, fn _url, :get_media_attributes_for_collection, _opts, _ot, _addl_opts ->
        response =
          Phoenix.json_library().encode!(%{
            id: "video3",
            title: "Video 3",
            live_status: "not_live",
            description: "desc3",
            # Only focusing on these because these are passed to functions that
            # could fail if they're not present
            original_url: nil,
            aspect_ratio: nil,
            duration: nil,
            upload_date: nil
          })

        {:ok, response}
      end)

      assert [changeset] = SlowIndexingHelpers.index_and_enqueue_download_for_media_items(source)

      assert %Ecto.Changeset{} = changeset
    end

    test "doesn't blow up if the media item cannot be saved", %{source: source} do
      stub(YtDlpRunnerMock, :run, fn _url, :get_media_attributes_for_collection, _opts, _ot, _addl_opts ->
        response =
          Phoenix.json_library().encode!(%{
            id: "video1",
            # This is a disallowed title - see MediaItem changeset or issue #549
            title: "youtube video #123",
            original_url: "https://example.com/video1",
            live_status: "not_live",
            description: "desc1",
            aspect_ratio: 1.67,
            duration: 12.34,
            upload_date: "20210101"
          })

        {:ok, response}
      end)

      assert [changeset] = SlowIndexingHelpers.index_and_enqueue_download_for_media_items(source)

      assert %Ecto.Changeset{} = changeset
    end

    test "passes the source's download options to the yt-dlp runner", %{source: source} do
      expect(YtDlpRunnerMock, :run, fn _url, :get_media_attributes_for_collection, opts, _ot, _addl_opts ->
        assert {:output, "/tmp/test/media/%(title)S.%(ext)S"} in opts
        assert {:remux_video, "mp4"} in opts
        {:ok, source_attributes_return_fixture()}
      end)

      SlowIndexingHelpers.index_and_enqueue_download_for_media_items(source)
    end
  end

  describe "index_and_enqueue_download_for_media_items/2 when testing cookies" do
    test "sets use_cookies if the source uses cookies" do
      expect(YtDlpRunnerMock, :run, fn _url, :get_media_attributes_for_collection, _opts, _ot, addl_opts ->
        assert {:use_cookies, true} in addl_opts
        {:ok, source_attributes_return_fixture()}
      end)

      source = source_fixture(%{cookie_behaviour: :all_operations})

      SlowIndexingHelpers.index_and_enqueue_download_for_media_items(source)
    end

    test "sets use_cookies if the source uses cookies when needed" do
      expect(YtDlpRunnerMock, :run, fn _url, :get_media_attributes_for_collection, _opts, _ot, addl_opts ->
        assert {:use_cookies, true} in addl_opts
        {:ok, source_attributes_return_fixture()}
      end)

      source = source_fixture(%{cookie_behaviour: :when_needed})

      SlowIndexingHelpers.index_and_enqueue_download_for_media_items(source)
    end

    test "doesn't set use_cookies if the source doesn't use cookies" do
      expect(YtDlpRunnerMock, :run, fn _url, :get_media_attributes_for_collection, _opts, _ot, addl_opts ->
        assert {:use_cookies, false} in addl_opts
        {:ok, source_attributes_return_fixture()}
      end)

      source = source_fixture(%{cookie_behaviour: :disabled})

      SlowIndexingHelpers.index_and_enqueue_download_for_media_items(source)
    end
  end

  describe "index_and_enqueue_download_for_media_items/2 when testing file watcher" do
    test "creates a new media item for everything already in the file", %{source: source} do
      watcher_poll_interval = Application.get_env(:pinchflat, :file_watcher_poll_interval)

      stub(YtDlpRunnerMock, :run, fn _url, :get_media_attributes_for_collection, _opts, _ot, addl_opts ->
        filepath = Keyword.get(addl_opts, :output_filepath)
        File.write(filepath, source_attributes_return_fixture())

        # Need to add a delay to ensure the file watcher has time to read the file
        :timer.sleep(watcher_poll_interval * 2)
        # We know we're testing the file watcher since the syncronous call will only
        # return an empty string (creating no records)
        {:ok, ""}
      end)

      assert Repo.aggregate(MediaItem, :count, :id) == 0
      SlowIndexingHelpers.index_and_enqueue_download_for_media_items(source)
      assert Repo.aggregate(MediaItem, :count, :id) == 3
    end

    test "enqueues a download for everything already in the file", %{source: source} do
      watcher_poll_interval = Application.get_env(:pinchflat, :file_watcher_poll_interval)

      stub(YtDlpRunnerMock, :run, fn _url, :get_media_attributes_for_collection, _opts, _ot, addl_opts ->
        filepath = Keyword.get(addl_opts, :output_filepath)
        File.write(filepath, source_attributes_return_fixture())

        # Need to add a delay to ensure the file watcher has time to read the file
        :timer.sleep(watcher_poll_interval * 2)
        # We know we're testing the file watcher since the syncronous call will only
        # return an empty string (creating no records)
        {:ok, ""}
      end)

      refute_enqueued(worker: MediaDownloadWorker)
      SlowIndexingHelpers.index_and_enqueue_download_for_media_items(source)
      assert_enqueued(worker: MediaDownloadWorker)
    end

    test "does not enqueue downloads if the source is set to not download" do
      watcher_poll_interval = Application.get_env(:pinchflat, :file_watcher_poll_interval)
      source = source_fixture(download_media: false)

      stub(YtDlpRunnerMock, :run, fn _url, :get_media_attributes_for_collection, _opts, _ot, addl_opts ->
        filepath = Keyword.get(addl_opts, :output_filepath)
        File.write(filepath, source_attributes_return_fixture())

        # Need to add a delay to ensure the file watcher has time to read the file
        :timer.sleep(watcher_poll_interval * 2)
        # We know we're testing the file watcher since the syncronous call will only
        # return an empty string (creating no records)
        {:ok, ""}
      end)

      SlowIndexingHelpers.index_and_enqueue_download_for_media_items(source)
      refute_enqueued(worker: MediaDownloadWorker)
    end

    test "does not enqueue downloads for media that doesn't match the profile's format options" do
      watcher_poll_interval = Application.get_env(:pinchflat, :file_watcher_poll_interval)
      profile = media_profile_fixture(%{shorts_behaviour: :exclude})
      source = source_fixture(%{media_profile_id: profile.id})

      stub(YtDlpRunnerMock, :run, fn _url, :get_media_attributes_for_collection, _opts, _ot, addl_opts ->
        filepath = Keyword.get(addl_opts, :output_filepath)

        contents =
          Phoenix.json_library().encode!(%{
            id: "video2",
            title: "Video 2",
            original_url: "https://example.com/shorts/video2",
            live_status: "is_live",
            description: "desc2",
            aspect_ratio: 1.67,
            duration: 345.67,
            upload_date: "20210101"
          })

        File.write(filepath, contents)

        # Need to add a delay to ensure the file watcher has time to read the file
        :timer.sleep(watcher_poll_interval * 2)
        # We know we're testing the file watcher since the syncronous call will only
        # return an empty string (creating no records)
        {:ok, ""}
      end)

      SlowIndexingHelpers.index_and_enqueue_download_for_media_items(source)
      refute_enqueued(worker: MediaDownloadWorker)
    end

    test "does not enqueue multiple download jobs for the same media items", %{source: source} do
      watcher_poll_interval = Application.get_env(:pinchflat, :file_watcher_poll_interval)

      stub(YtDlpRunnerMock, :run, fn _url, :get_media_attributes_for_collection, _opts, _ot, addl_opts ->
        filepath = Keyword.get(addl_opts, :output_filepath)
        File.write(filepath, source_attributes_return_fixture())

        # Need to add a delay to ensure the file watcher has time to read the file
        :timer.sleep(watcher_poll_interval * 2)
        # This also returns the final result to the yt-dlp call (like the real usage actually would do)
        # so it'll attempt to create the media items and enqueue the download jobs based on this as well
        {:ok, source_attributes_return_fixture()}
      end)

      SlowIndexingHelpers.index_and_enqueue_download_for_media_items(source)
      assert Repo.aggregate(MediaItem, :count, :id) == 3
      assert [_, _, _] = all_enqueued(worker: MediaDownloadWorker)
    end

    test "does not blow up if the file returns invalid json", %{source: source} do
      watcher_poll_interval = Application.get_env(:pinchflat, :file_watcher_poll_interval)

      stub(YtDlpRunnerMock, :run, fn _url, :get_media_attributes_for_collection, _opts, _ot, addl_opts ->
        filepath = Keyword.get(addl_opts, :output_filepath)
        File.write(filepath, "INVALID")

        # Need to add a delay to ensure the file watcher has time to read the file
        :timer.sleep(watcher_poll_interval * 2)
        # We know we're testing the file watcher since the syncronous call will only
        # return an empty string (creating no records)
        {:ok, ""}
      end)

      assert [] = SlowIndexingHelpers.index_and_enqueue_download_for_media_items(source)
    end
  end

  describe "index_and_enqueue_download_for_media_items when testing the download archive" do
    test "a download archive is used if the source is a channel that has been indexed before" do
      source = source_fixture(%{collection_type: :channel, last_indexed_at: now()})

      expect(YtDlpRunnerMock, :run, fn _url, :get_media_attributes_for_collection, opts, _ot, _addl_opts ->
        assert :break_on_existing in opts
        assert Keyword.has_key?(opts, :download_archive)

        {:ok, source_attributes_return_fixture()}
      end)

      SlowIndexingHelpers.index_and_enqueue_download_for_media_items(source)
    end

    test "a download archive is not used if the source is not a channel" do
      source = source_fixture(%{collection_type: :playlist})

      expect(YtDlpRunnerMock, :run, fn _url, :get_media_attributes_for_collection, opts, _ot, _addl_opts ->
        refute :break_on_existing in opts
        refute Keyword.has_key?(opts, :download_archive)

        {:ok, source_attributes_return_fixture()}
      end)

      SlowIndexingHelpers.index_and_enqueue_download_for_media_items(source)
    end

    test "a download archive is not used if the source has never been indexed before" do
      source = source_fixture(%{collection_type: :channel, last_indexed_at: nil})

      expect(YtDlpRunnerMock, :run, fn _url, :get_media_attributes_for_collection, opts, _ot, _addl_opts ->
        refute :break_on_existing in opts
        refute Keyword.has_key?(opts, :download_archive)

        {:ok, source_attributes_return_fixture()}
      end)

      SlowIndexingHelpers.index_and_enqueue_download_for_media_items(source)
    end

    test "a download archive is not used if the index has been forced to run" do
      source = source_fixture(%{collection_type: :channel})

      expect(YtDlpRunnerMock, :run, fn _url, :get_media_attributes_for_collection, opts, _ot, _addl_opts ->
        refute :break_on_existing in opts
        refute Keyword.has_key?(opts, :download_archive)

        {:ok, source_attributes_return_fixture()}
      end)

      SlowIndexingHelpers.index_and_enqueue_download_for_media_items(source, was_forced: true)
    end

    test "the download archive is formatted correctly and contains the right video" do
      source = source_fixture(%{collection_type: :channel, last_indexed_at: now()})

      media_items =
        1..21
        |> Enum.map(fn n ->
          media_item_fixture(%{source_id: source.id, uploaded_at: now_minus(n, :days)})
        end)

      expect(YtDlpRunnerMock, :run, fn _url, :get_media_attributes_for_collection, opts, _ot, _addl_opts ->
        archive_file = Keyword.get(opts, :download_archive)
        last_media_item = List.last(media_items)

        assert File.read!(archive_file) == "youtube #{last_media_item.media_id}"

        {:ok, source_attributes_return_fixture()}
      end)

      SlowIndexingHelpers.index_and_enqueue_download_for_media_items(source)
    end
  end
end
