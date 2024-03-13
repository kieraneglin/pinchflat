defmodule Pinchflat.Downloading.DownloadingHelpersTest do
  use Pinchflat.DataCase

  import Mox
  import Pinchflat.MediaFixtures
  import Pinchflat.SourcesFixtures

  alias Pinchflat.Tasks
  alias Pinchflat.Downloading.DownloadingHelpers
  alias Pinchflat.Downloading.MediaDownloadWorker

  setup :verify_on_exit!

  describe "enqueue_pending_download_tasks/1" do
    test "it enqueues a job for each pending media item" do
      source = source_fixture()
      media_item = media_item_fixture(source_id: source.id, media_filepath: nil)

      assert :ok = DownloadingHelpers.enqueue_pending_download_tasks(source)

      assert_enqueued(worker: MediaDownloadWorker, args: %{"id" => media_item.id})
    end

    test "it does not enqueue a job for media items with a filepath" do
      source = source_fixture()
      _media_item = media_item_fixture(source_id: source.id, media_filepath: "some/filepath.mp4")

      assert :ok = DownloadingHelpers.enqueue_pending_download_tasks(source)

      refute_enqueued(worker: MediaDownloadWorker)
    end

    test "it attaches a task to each enqueued job" do
      source = source_fixture()
      media_item = media_item_fixture(source_id: source.id, media_filepath: nil)

      assert [] = Tasks.list_tasks_for(:media_item_id, media_item.id)

      assert :ok = DownloadingHelpers.enqueue_pending_download_tasks(source)

      assert [_] = Tasks.list_tasks_for(:media_item_id, media_item.id)
    end

    test "it does not create a job if the source is set to not download" do
      source = source_fixture(download_media: false)

      assert :ok = DownloadingHelpers.enqueue_pending_download_tasks(source)

      refute_enqueued(worker: MediaDownloadWorker)
    end

    test "it does not attach tasks if the source is set to not download" do
      source = source_fixture(download_media: false)
      media_item = media_item_fixture(source_id: source.id, media_filepath: nil)

      assert :ok = DownloadingHelpers.enqueue_pending_download_tasks(source)
      assert [] = Tasks.list_tasks_for(:media_item_id, media_item.id)
    end
  end

  describe "dequeue_pending_download_tasks/1" do
    test "it deletes all pending tasks for a source's media items" do
      source = source_fixture()
      media_item = media_item_fixture(source_id: source.id, media_filepath: nil)

      DownloadingHelpers.enqueue_pending_download_tasks(source)
      assert_enqueued(worker: MediaDownloadWorker, args: %{"id" => media_item.id})

      assert :ok = DownloadingHelpers.dequeue_pending_download_tasks(source)

      refute_enqueued(worker: MediaDownloadWorker)
      assert [] = Tasks.list_tasks_for(:media_item_id, media_item.id)
    end
  end
end
