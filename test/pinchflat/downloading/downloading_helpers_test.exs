defmodule Pinchflat.Downloading.DownloadingHelpersTest do
  use Pinchflat.DataCase

  import Mox
  import Pinchflat.MediaFixtures
  import Pinchflat.SourcesFixtures
  import Pinchflat.ProfilesFixtures

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

      assert [] = Tasks.list_tasks_for(media_item)

      assert :ok = DownloadingHelpers.enqueue_pending_download_tasks(source)

      assert [_] = Tasks.list_tasks_for(media_item)
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
      assert [] = Tasks.list_tasks_for(media_item)
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
      assert [] = Tasks.list_tasks_for(media_item)
    end
  end

  describe "kickoff_download_if_pending/1" do
    setup do
      media_item = media_item_fixture(media_filepath: nil)

      {:ok, media_item: media_item}
    end

    test "enqueues a download job", %{media_item: media_item} do
      assert {:ok, _} = DownloadingHelpers.kickoff_download_if_pending(media_item)

      assert_enqueued(worker: MediaDownloadWorker, args: %{"id" => media_item.id})
    end

    test "creates and returns a download task record", %{media_item: media_item} do
      assert {:ok, task} = DownloadingHelpers.kickoff_download_if_pending(media_item)

      assert [found_task] = Tasks.list_tasks_for(media_item, "MediaDownloadWorker")
      assert task.id == found_task.id
    end

    test "does not enqueue a download job if the source does not allow it" do
      source = source_fixture(%{download_media: false})
      media_item = media_item_fixture(source_id: source.id, media_filepath: nil)

      assert {:error, :should_not_download} = DownloadingHelpers.kickoff_download_if_pending(media_item)

      refute_enqueued(worker: MediaDownloadWorker)
    end

    test "does not enqueue a download job if the media item does not match the format rules" do
      profile = media_profile_fixture(%{livestream_behaviour: :exclude})
      source = source_fixture(%{media_profile_id: profile.id})
      media_item = media_item_fixture(source_id: source.id, media_filepath: nil, livestream: true)

      assert {:error, :should_not_download} = DownloadingHelpers.kickoff_download_if_pending(media_item)

      refute_enqueued(worker: MediaDownloadWorker)
    end
  end
end
