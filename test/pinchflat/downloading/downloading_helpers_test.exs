defmodule Pinchflat.Downloading.DownloadingHelpersTest do
  use Pinchflat.DataCase

  import Pinchflat.MediaFixtures
  import Pinchflat.SourcesFixtures
  import Pinchflat.ProfilesFixtures

  alias Pinchflat.Tasks
  alias Pinchflat.Media.MediaItem
  alias Pinchflat.Utils.FilesystemUtils
  alias Pinchflat.Downloading.DownloadingHelpers
  alias Pinchflat.Downloading.MediaDownloadWorker

  alias Pinchflat.YtDlp.Media, as: YtDlpMedia

  describe "enqueue_pending_download_tasks/1" do
    test "it enqueues a job for each pending media item" do
      source = source_fixture()
      media_item = media_item_fixture(source_id: source.id, media_filepath: nil)

      assert :ok = DownloadingHelpers.enqueue_pending_download_tasks(source)

      assert_enqueued(worker: MediaDownloadWorker, args: %{"id" => media_item.id})
    end

    test "it can optionally delay when those jobs are enqueued" do
      source = source_fixture()
      _media_item = media_item_fixture(source_id: source.id, media_filepath: nil)

      assert :ok = DownloadingHelpers.enqueue_pending_download_tasks(source, kickoff_delay: 60)
      [job] = all_enqueued(worker: MediaDownloadWorker)

      assert_in_delta DateTime.diff(job.scheduled_at, now()), 60, 1
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

    test "it can optionally delay when those jobs are enqueued", %{media_item: media_item} do
      assert {:ok, _} = DownloadingHelpers.kickoff_download_if_pending(media_item, kickoff_delay: 60)
      [job] = all_enqueued(worker: MediaDownloadWorker)

      assert_in_delta DateTime.diff(job.scheduled_at, now()), 60, 1
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

  describe "kickoff_redownload_for_existing_media/1" do
    test "enqueues a download job for each downloaded media item" do
      source = source_fixture()
      media_item = media_item_fixture(source_id: source.id, media_filepath: "some/filepath.mp4")

      assert [{:ok, _}] = DownloadingHelpers.kickoff_redownload_for_existing_media(source)

      assert_enqueued(worker: MediaDownloadWorker, args: %{"id" => media_item.id})
    end

    test "doesn't enqueue jobs for media that should be ignored" do
      source = source_fixture()
      other_source = source_fixture()
      _not_downloaded = media_item_fixture(source_id: source.id, media_filepath: nil)
      _other_source = media_item_fixture(source_id: other_source.id, media_filepath: "some/filepath.mp4")

      _download_prevented =
        media_item_fixture(source_id: source.id, media_filepath: "some/filepath.mp4", prevent_download: true)

      _culled =
        media_item_fixture(source_id: source.id, media_filepath: "some/filepath.mp4", culled_at: now())

      assert [] = DownloadingHelpers.kickoff_redownload_for_existing_media(source)

      refute_enqueued(worker: MediaDownloadWorker)
    end
  end

  describe "create_media_item_and_run_script/2" do
    setup do
      FilesystemUtils.write_p!(filepath(), "")
      File.chmod(filepath(), 0o755)

      on_exit(fn -> File.rm(filepath()) end)

      source = source_fixture()

      media_attrs =
        media_attributes_return_fixture()
        |> Phoenix.json_library().decode!()
        |> YtDlpMedia.response_to_struct()

      {:ok, source: source, media_attrs: media_attrs}
    end

    test "creates a media item for a given source and attributes", %{source: source, media_attrs: media_attrs} do
      assert {:ok, %MediaItem{} = media_item} = DownloadingHelpers.create_media_item_and_run_script(source, media_attrs)

      assert media_item.source_id == source.id
      assert media_item.title == media_attrs.title
      assert media_item.media_id == media_attrs.media_id
      assert media_item.original_url == media_attrs.original_url
      assert media_item.description == media_attrs.description
    end

    test "returns an error if the media item cannot be created", %{source: source, media_attrs: media_attrs} do
      media_attrs = %YtDlpMedia{media_attrs | media_id: nil}

      assert {:error, %Ecto.Changeset{}} = DownloadingHelpers.create_media_item_and_run_script(source, media_attrs)
    end

    test "runs a script if the media item is created", %{source: source, media_attrs: media_attrs} do
      # We *love* indirectly testing side effects
      tmp_dir = Application.get_env(:pinchflat, :tmpfile_directory)
      filename = "#{tmp_dir}/test_file-#{Enum.random(1..1000)}"
      File.write(filepath(), "#!/bin/bash\ntouch #{filename}\n")

      refute File.exists?(filename)
      assert {:ok, %MediaItem{}} = DownloadingHelpers.create_media_item_and_run_script(source, media_attrs)
      assert File.exists?(filename)
    end

    test "does not run a script if the media item already exists", %{source: source, media_attrs: media_attrs} do
      {:ok, %MediaItem{}} = DownloadingHelpers.create_media_item_and_run_script(source, media_attrs)

      tmp_dir = Application.get_env(:pinchflat, :tmpfile_directory)
      filename = "#{tmp_dir}/test_file-#{Enum.random(1..1000)}"
      File.write(filepath(), "#!/bin/bash\ntouch #{filename}\n")

      refute File.exists?(filename)
      assert {:ok, %MediaItem{}} = DownloadingHelpers.create_media_item_and_run_script(source, media_attrs)
      refute File.exists?(filename)
    end

    defp filepath do
      base_dir = Application.get_env(:pinchflat, :extras_directory)

      Path.join([base_dir, "user-scripts", "lifecycle"])
    end
  end
end
