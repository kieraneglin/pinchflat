defmodule Pinchflat.Downloading.MediaDownloadWorkerTest do
  use Pinchflat.DataCase

  import Mox
  import Pinchflat.MediaFixtures

  alias Pinchflat.Media
  alias Pinchflat.Sources
  alias Pinchflat.Utils.FilesystemUtils
  alias Pinchflat.Downloading.MediaDownloadWorker

  setup :verify_on_exit!

  setup do
    stub(HTTPClientMock, :get, fn _url, _headers, _opts ->
      {:ok, ""}
    end)

    media_item =
      %{media_filepath: nil}
      |> media_item_fixture()
      |> Repo.preload([:metadata, source: :media_profile])

    {:ok, %{media_item: media_item}}
  end

  describe "kickoff_with_task/2" do
    test "starts the worker", %{media_item: media_item} do
      assert [] = all_enqueued(worker: MediaDownloadWorker)
      assert {:ok, _} = MediaDownloadWorker.kickoff_with_task(media_item)
      assert [_] = all_enqueued(worker: MediaDownloadWorker)
    end

    test "attaches a task", %{media_item: media_item} do
      assert {:ok, task} = MediaDownloadWorker.kickoff_with_task(media_item)
      assert task.media_item_id == media_item.id
    end

    test "can be called with additional job arguments", %{media_item: media_item} do
      job_args = %{"force" => true}

      assert {:ok, _} = MediaDownloadWorker.kickoff_with_task(media_item, job_args)

      assert_enqueued(worker: MediaDownloadWorker, args: %{"id" => media_item.id, "force" => true})
    end

    test "can be called with additional job options", %{media_item: media_item} do
      job_opts = [max_attempts: 5]

      assert {:ok, _} = MediaDownloadWorker.kickoff_with_task(media_item, %{}, job_opts)

      [job] = all_enqueued(worker: MediaDownloadWorker, args: %{"id" => media_item.id})
      assert job.max_attempts == 5
    end
  end

  describe "perform/1" do
    test "it saves attributes to the media_item", %{media_item: media_item} do
      expect(YtDlpRunnerMock, :run, fn _url, _opts, _ot, _addl ->
        {:ok, render_metadata(:media_metadata)}
      end)

      assert media_item.media_filepath == nil
      perform_job(MediaDownloadWorker, %{id: media_item.id})
      media_item = Repo.reload(media_item)

      assert media_item.media_filepath != nil
    end

    test "it saves the metadata to the media_item", %{media_item: media_item} do
      expect(YtDlpRunnerMock, :run, fn _url, _opts, _ot, _addl ->
        {:ok, render_metadata(:media_metadata)}
      end)

      assert media_item.metadata == nil
      perform_job(MediaDownloadWorker, %{id: media_item.id})
      assert Repo.reload(media_item).metadata != nil
    end

    test "it won't double-schedule downloading jobs", %{media_item: media_item} do
      Oban.insert(MediaDownloadWorker.new(%{id: media_item.id}))
      Oban.insert(MediaDownloadWorker.new(%{id: media_item.id}))

      assert [_] = all_enqueued(worker: MediaDownloadWorker)
    end

    test "it sets the job to retryable if the download fails", %{media_item: media_item} do
      expect(YtDlpRunnerMock, :run, fn _url, _opts, _ot, _addl -> {:error, "error"} end)

      Oban.Testing.with_testing_mode(:inline, fn ->
        {:ok, job} = Oban.insert(MediaDownloadWorker.new(%{id: media_item.id}))

        assert job.state == "retryable"
      end)
    end

    test "sets the job to retryable if the download failed and was retried", %{media_item: media_item} do
      expect(YtDlpRunnerMock, :run, fn _url, _opts, _ot, _addl ->
        {:error, "Unable to communicate with SponsorBlock", 1}
      end)

      Oban.Testing.with_testing_mode(:inline, fn ->
        {:ok, job} = Oban.insert(MediaDownloadWorker.new(%{id: media_item.id}))

        assert job.state == "retryable"
      end)
    end

    test "it ensures error are returned in a 2-item tuple", %{media_item: media_item} do
      expect(YtDlpRunnerMock, :run, fn _url, _opts, _ot, _addl -> {:error, "error", 1} end)

      assert {:error, :download_failed} = perform_job(MediaDownloadWorker, %{id: media_item.id})
    end

    test "it does not download if the source is set to not download", %{media_item: media_item} do
      expect(YtDlpRunnerMock, :run, 0, fn _url, _opts, _ot, _addl -> :ok end)

      Sources.update_source(media_item.source, %{download_media: false})

      perform_job(MediaDownloadWorker, %{id: media_item.id})
    end

    test "does not download if the media item is set to not download", %{media_item: media_item} do
      expect(YtDlpRunnerMock, :run, 0, fn _url, _opts, _ot, _addl -> :ok end)

      Media.update_media_item(media_item, %{prevent_download: true})

      perform_job(MediaDownloadWorker, %{id: media_item.id})
    end

    test "downloads anyway if forced", %{media_item: media_item} do
      expect(YtDlpRunnerMock, :run, fn _url, _opts, _ot, _addl -> :ok end)

      Sources.update_source(media_item.source, %{download_media: false})
      Media.update_media_item(media_item, %{prevent_download: true})

      perform_job(MediaDownloadWorker, %{id: media_item.id, force: true})
    end

    test "it saves the file's size to the database", %{media_item: media_item} do
      expect(YtDlpRunnerMock, :run, fn _url, _opts, _ot, _addl ->
        metadata = render_parsed_metadata(:media_metadata)
        FilesystemUtils.write_p!(metadata["filepath"], "test")

        {:ok, Phoenix.json_library().encode!(metadata)}
      end)

      perform_job(MediaDownloadWorker, %{id: media_item.id})
      media_item = Repo.reload(media_item)

      assert media_item.media_size_bytes > 0
    end

    test "saves redownloaded_at if this is for a redownload", %{media_item: media_item} do
      expect(YtDlpRunnerMock, :run, fn _url, _opts, _ot, _addl ->
        {:ok, render_metadata(:media_metadata)}
      end)

      perform_job(MediaDownloadWorker, %{id: media_item.id, redownload?: true})
      media_item = Repo.reload(media_item)

      assert media_item.media_redownloaded_at != nil
    end

    test "doesn't save redownloaded_at if this is not for a redownload", %{media_item: media_item} do
      expect(YtDlpRunnerMock, :run, fn _url, _opts, _ot, _addl ->
        {:ok, render_metadata(:media_metadata)}
      end)

      perform_job(MediaDownloadWorker, %{id: media_item.id})
      media_item = Repo.reload(media_item)

      assert media_item.media_redownloaded_at == nil
    end

    test "does not blow up if the record doesn't exist" do
      assert :ok = perform_job(MediaDownloadWorker, %{id: 0})
    end
  end
end
