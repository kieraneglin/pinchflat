defmodule Pinchflat.Tasks.MediaItemTasksTest do
  use Pinchflat.DataCase

  import Mox
  import Pinchflat.MediaFixtures
  import Pinchflat.SourcesFixtures
  import Pinchflat.ProfilesFixtures

  alias Pinchflat.Tasks
  alias Pinchflat.Media.MediaItem
  alias Pinchflat.Tasks.MediaItemTasks
  alias Pinchflat.Workers.MediaDownloadWorker

  setup :verify_on_exit!

  @media_url "https://www.youtube.com/watch?v=1234"

  describe "compute_and_save_media_filesize/1" do
    test "updates the media item with the file size" do
      media_item = media_item_with_attachments()

      refute media_item.media_size_bytes

      assert {:ok, media_item} = MediaItemTasks.compute_and_save_media_filesize(media_item)

      assert Repo.reload!(media_item).media_size_bytes
    end

    test "returns the error if operation fails" do
      media_item = media_item_fixture(%{media_filepath: "/nonexistent/file.mkv"})

      assert {:error, _} = MediaItemTasks.compute_and_save_media_filesize(media_item)
    end
  end

  describe "index_and_enqueue_download_for_media_item/2" do
    setup do
      stub(YtDlpRunnerMock, :run, fn _url, _opts, _ot ->
        {:ok, media_attributes_return_fixture()}
      end)

      {:ok, [source: source_fixture()]}
    end

    test "creates a new media item based on the URL", %{source: source} do
      assert Repo.aggregate(MediaItem, :count) == 0
      assert {:ok, _} = MediaItemTasks.index_and_enqueue_download_for_media_item(source, @media_url)
      assert Repo.aggregate(MediaItem, :count) == 1
    end

    test "won't duplicate media_items based on media_id and source", %{source: source} do
      assert {:ok, _} = MediaItemTasks.index_and_enqueue_download_for_media_item(source, @media_url)
      assert {:error, _} = MediaItemTasks.index_and_enqueue_download_for_media_item(source, @media_url)

      assert Repo.aggregate(MediaItem, :count) == 1
    end

    test "enqueues a download job", %{source: source} do
      assert {:ok, media_item} = MediaItemTasks.index_and_enqueue_download_for_media_item(source, @media_url)

      assert_enqueued(worker: MediaDownloadWorker, args: %{"id" => media_item.id})
    end

    test "creates a download task record", %{source: source} do
      assert {:ok, media_item} = MediaItemTasks.index_and_enqueue_download_for_media_item(source, @media_url)

      assert [_] = Tasks.list_tasks_for(:media_item_id, media_item.id, "MediaDownloadWorker")
    end

    test "does not enqueue a download job if the source does not allow it" do
      source = source_fixture(%{download_media: false})

      assert {:ok, _} = MediaItemTasks.index_and_enqueue_download_for_media_item(source, @media_url)

      refute_enqueued(worker: MediaDownloadWorker)
    end

    test "does not enqueue a download job if the media item does not match the format rules" do
      profile = media_profile_fixture(%{shorts_behaviour: :exclude})
      source = source_fixture(%{media_profile_id: profile.id})

      stub(YtDlpRunnerMock, :run, fn _url, _opts, _ot ->
        output =
          Phoenix.json_library().encode!(%{
            id: "video2",
            title: "Video 2",
            webpage_url: "https://example.com/shorts/video2",
            was_live: true,
            description: "desc2",
            aspect_ratio: 1.67,
            duration: 345.67
          })

        {:ok, output}
      end)

      assert {:ok, _media_item} = MediaItemTasks.index_and_enqueue_download_for_media_item(source, @media_url)
      refute_enqueued(worker: MediaDownloadWorker)
    end
  end
end
