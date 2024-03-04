defmodule Pinchflat.Tasks.SourceTasksTest do
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
  alias Pinchflat.Workers.MediaIndexingWorker
  alias Pinchflat.Workers.VideoDownloadWorker

  setup :verify_on_exit!

  describe "kickoff_indexing_task/1" do
    test "it schedules a job" do
      source = source_fixture(index_frequency_minutes: 1)

      assert {:ok, _} = SourceTasks.kickoff_indexing_task(source)

      assert_enqueued(worker: MediaIndexingWorker, args: %{"id" => source.id})
    end

    test "it creates and attaches a task" do
      source = source_fixture(index_frequency_minutes: 1)

      assert {:ok, %Task{} = task} = SourceTasks.kickoff_indexing_task(source)

      assert task.source_id == source.id
    end

    test "it deletes any pending tasks for the source" do
      source = source_fixture()
      {:ok, job} = Oban.insert(MediaIndexingWorker.new(%{"id" => source.id}))
      task = task_fixture(source_id: source.id, job_id: job.id)

      assert {:ok, _} = SourceTasks.kickoff_indexing_task(source)

      assert_raise Ecto.NoResultsError, fn -> Repo.reload!(task) end
    end
  end

  describe "index_and_enqueue_download_for_media_items/1" do
    setup do
      stub(YtDlpRunnerMock, :run, fn _url, _opts, _ot, _addl_opts ->
        {:ok, source_attributes_return_fixture()}
      end)

      {:ok, [source: source_fixture()]}
    end

    test "it creates a media_item record for each media ID returned", %{source: source} do
      assert media_items = SourceTasks.index_and_enqueue_download_for_media_items(source)

      assert Enum.count(media_items) == 3
      assert ["video1", "video2", "video3"] == Enum.map(media_items, & &1.media_id)
      assert ["Video 1", "Video 2", "Video 3"] == Enum.map(media_items, & &1.title)
      assert ["desc1", "desc2", "desc3"] == Enum.map(media_items, & &1.description)
      assert Enum.all?(media_items, fn mi -> mi.original_url end)
      assert Enum.all?(media_items, fn %MediaItem{} -> true end)
    end

    test "it attaches all media_items to the given source", %{source: source} do
      source_id = source.id
      assert media_items = SourceTasks.index_and_enqueue_download_for_media_items(source)

      assert Enum.count(media_items) == 3
      assert Enum.all?(media_items, fn %MediaItem{source_id: ^source_id} -> true end)
    end

    test "it won't duplicate media_items based on media_id and source", %{source: source} do
      _first_run = SourceTasks.index_and_enqueue_download_for_media_items(source)
      _duplicate_run = SourceTasks.index_and_enqueue_download_for_media_items(source)

      media_items = Repo.preload(source, :media_items).media_items
      assert Enum.count(media_items) == 3
    end

    test "it can duplicate media_ids for different sources", %{source: source} do
      other_source = source_fixture()

      media_items = SourceTasks.index_and_enqueue_download_for_media_items(source)
      media_items_other_source = SourceTasks.index_and_enqueue_download_for_media_items(other_source)

      assert Enum.count(media_items) == 3
      assert Enum.count(media_items_other_source) == 3

      assert Enum.map(media_items, & &1.media_id) ==
               Enum.map(media_items_other_source, & &1.media_id)
    end

    test "it returns a list of media_items or changesets", %{source: source} do
      first_run = SourceTasks.index_and_enqueue_download_for_media_items(source)
      duplicate_run = SourceTasks.index_and_enqueue_download_for_media_items(source)

      assert Enum.all?(first_run, fn %MediaItem{} -> true end)
      assert Enum.all?(duplicate_run, fn %Ecto.Changeset{} -> true end)
    end

    test "it updates the source's last_indexed_at field", %{source: source} do
      assert source.last_indexed_at == nil

      SourceTasks.index_and_enqueue_download_for_media_items(source)
      source = Repo.reload!(source)

      assert DateTime.diff(DateTime.utc_now(), source.last_indexed_at) < 2
    end

    test "it enqueues a job for each pending media item" do
      source = source_fixture()
      media_item = media_item_fixture(source_id: source.id, media_filepath: nil)

      SourceTasks.index_and_enqueue_download_for_media_items(source)

      assert_enqueued(worker: VideoDownloadWorker, args: %{"id" => media_item.id})
    end

    test "it does not attach tasks if the source is set to not download" do
      source = source_fixture(download_media: false)
      media_item = media_item_fixture(source_id: source.id, media_filepath: nil)

      SourceTasks.index_and_enqueue_download_for_media_items(source)

      assert [] = Tasks.list_tasks_for(:media_item_id, media_item.id)
    end
  end

  describe "index_and_enqueue_download_for_media_items/1 when testing file watcher" do
    setup do
      {:ok, [source: source_fixture()]}
    end

    test "creates a new media item for everything already in the file", %{source: source} do
      watcher_poll_interval = Application.get_env(:pinchflat, :file_watcher_poll_interval)

      stub(YtDlpRunnerMock, :run, fn _url, _opts, _ot, addl_opts ->
        filepath = Keyword.get(addl_opts, :output_filepath)
        File.write(filepath, source_attributes_return_fixture())

        # Need to add a delay to ensure the file watcher has time to read the file
        :timer.sleep(watcher_poll_interval * 2)
        # We know we're testing the file watcher since the syncronous call will only
        # return an empty string (creating no records)
        {:ok, ""}
      end)

      assert Repo.aggregate(MediaItem, :count, :id) == 0
      SourceTasks.index_and_enqueue_download_for_media_items(source)
      assert Repo.aggregate(MediaItem, :count, :id) == 3
    end

    test "enqueues a download for everything already in the file", %{source: source} do
      watcher_poll_interval = Application.get_env(:pinchflat, :file_watcher_poll_interval)

      stub(YtDlpRunnerMock, :run, fn _url, _opts, _ot, addl_opts ->
        filepath = Keyword.get(addl_opts, :output_filepath)
        File.write(filepath, source_attributes_return_fixture())

        # Need to add a delay to ensure the file watcher has time to read the file
        :timer.sleep(watcher_poll_interval * 2)
        # We know we're testing the file watcher since the syncronous call will only
        # return an empty string (creating no records)
        {:ok, ""}
      end)

      refute_enqueued(worker: VideoDownloadWorker)
      SourceTasks.index_and_enqueue_download_for_media_items(source)
      assert_enqueued(worker: VideoDownloadWorker)
    end

    test "does not enqueue downloads if the source is set to not download" do
      watcher_poll_interval = Application.get_env(:pinchflat, :file_watcher_poll_interval)
      source = source_fixture(download_media: false)

      stub(YtDlpRunnerMock, :run, fn _url, _opts, _ot, addl_opts ->
        filepath = Keyword.get(addl_opts, :output_filepath)
        File.write(filepath, source_attributes_return_fixture())

        # Need to add a delay to ensure the file watcher has time to read the file
        :timer.sleep(watcher_poll_interval * 2)
        # We know we're testing the file watcher since the syncronous call will only
        # return an empty string (creating no records)
        {:ok, ""}
      end)

      SourceTasks.index_and_enqueue_download_for_media_items(source)
      refute_enqueued(worker: VideoDownloadWorker)
    end

    test "does not enqueue downloads for media that doesn't match the profile's format options" do
      watcher_poll_interval = Application.get_env(:pinchflat, :file_watcher_poll_interval)
      profile = media_profile_fixture(%{shorts_behaviour: :exclude})
      source = source_fixture(%{media_profile_id: profile.id})

      stub(YtDlpRunnerMock, :run, fn _url, _opts, _ot, addl_opts ->
        filepath = Keyword.get(addl_opts, :output_filepath)

        contents =
          Phoenix.json_library().encode!(%{
            id: "video2",
            title: "Video 2",
            original_url: "https://example.com/shorts/video2",
            was_live: true,
            description: "desc2"
          })

        File.write(filepath, contents)

        # Need to add a delay to ensure the file watcher has time to read the file
        :timer.sleep(watcher_poll_interval * 2)
        # We know we're testing the file watcher since the syncronous call will only
        # return an empty string (creating no records)
        {:ok, ""}
      end)

      SourceTasks.index_and_enqueue_download_for_media_items(source)
      refute_enqueued(worker: VideoDownloadWorker)
    end
  end

  describe "enqueue_pending_media_tasks/1" do
    test "it enqueues a job for each pending media item" do
      source = source_fixture()
      media_item = media_item_fixture(source_id: source.id, media_filepath: nil)

      assert :ok = SourceTasks.enqueue_pending_media_tasks(source)

      assert_enqueued(worker: VideoDownloadWorker, args: %{"id" => media_item.id})
    end

    test "it does not enqueue a job for media items with a filepath" do
      source = source_fixture()
      _media_item = media_item_fixture(source_id: source.id, media_filepath: "some/filepath.mp4")

      assert :ok = SourceTasks.enqueue_pending_media_tasks(source)

      refute_enqueued(worker: VideoDownloadWorker)
    end

    test "it attaches a task to each enqueued job" do
      source = source_fixture()
      media_item = media_item_fixture(source_id: source.id, media_filepath: nil)

      assert [] = Tasks.list_tasks_for(:media_item_id, media_item.id)

      assert :ok = SourceTasks.enqueue_pending_media_tasks(source)

      assert [_] = Tasks.list_tasks_for(:media_item_id, media_item.id)
    end

    test "it does not create a job if the source is set to not download" do
      source = source_fixture(download_media: false)

      assert :ok = SourceTasks.enqueue_pending_media_tasks(source)

      refute_enqueued(worker: VideoDownloadWorker)
    end

    test "it does not attach tasks if the source is set to not download" do
      source = source_fixture(download_media: false)
      media_item = media_item_fixture(source_id: source.id, media_filepath: nil)

      assert :ok = SourceTasks.enqueue_pending_media_tasks(source)
      assert [] = Tasks.list_tasks_for(:media_item_id, media_item.id)
    end
  end

  describe "dequeue_pending_media_tasks/1" do
    test "it deletes all pending tasks for a source's media items" do
      source = source_fixture()
      media_item = media_item_fixture(source_id: source.id, media_filepath: nil)

      SourceTasks.enqueue_pending_media_tasks(source)
      assert_enqueued(worker: VideoDownloadWorker, args: %{"id" => media_item.id})

      assert :ok = SourceTasks.dequeue_pending_media_tasks(source)

      refute_enqueued(worker: VideoDownloadWorker)
      assert [] = Tasks.list_tasks_for(:media_item_id, media_item.id)
    end
  end
end
