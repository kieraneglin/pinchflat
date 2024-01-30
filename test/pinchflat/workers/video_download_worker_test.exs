defmodule Pinchflat.Workers.VideoDownloadWorkerTest do
  use Pinchflat.DataCase

  import Mox
  import Pinchflat.MediaFixtures

  alias Pinchflat.Workers.VideoDownloadWorker

  setup :verify_on_exit!

  setup do
    media_item =
      Repo.preload(
        media_item_fixture(%{video_filepath: nil}),
        [:metadata, channel: :media_profile]
      )

    {:ok, %{media_item: media_item}}
  end

  describe "perform/1" do
    test "it saves attributes to the media_item", %{media_item: media_item} do
      expect(YtDlpRunnerMock, :run, fn _url, _opts, _ot ->
        {:ok, render_metadata(:media_metadata)}
      end)

      assert media_item.video_filepath == nil
      perform_job(VideoDownloadWorker, %{id: media_item.id})
      assert Repo.reload(media_item).video_filepath != nil
    end

    test "it saves the metadata to the media_item", %{media_item: media_item} do
      expect(YtDlpRunnerMock, :run, fn _url, _opts, _ot ->
        {:ok, render_metadata(:media_metadata)}
      end)

      assert media_item.metadata == nil
      perform_job(VideoDownloadWorker, %{id: media_item.id})
      assert Repo.reload(media_item).metadata != nil
    end

    test "it won't double-schedule downloading jobs", %{media_item: media_item} do
      Oban.insert(VideoDownloadWorker.new(%{id: media_item.id}))
      Oban.insert(VideoDownloadWorker.new(%{id: media_item.id}))

      assert [_] = all_enqueued(worker: VideoDownloadWorker)
    end

    test "it sets the job to retryable if the download fails", %{media_item: media_item} do
      expect(YtDlpRunnerMock, :run, fn _url, _opts, _ot -> {:error, "error"} end)

      Oban.Testing.with_testing_mode(:inline, fn ->
        {:ok, job} = Oban.insert(VideoDownloadWorker.new(%{id: media_item.id}))

        assert job.state == "retryable"
      end)
    end
  end
end
