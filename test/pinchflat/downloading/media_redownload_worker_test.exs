defmodule Pinchflat.Downloading.MediaRedownloadWorkerTest do
  use Pinchflat.DataCase

  import Pinchflat.MediaFixtures
  import Pinchflat.SourcesFixtures
  import Pinchflat.ProfilesFixtures

  alias Pinchflat.Downloading.MediaDownloadWorker
  alias Pinchflat.Downloading.MediaRedownloadWorker

  describe "perform/1" do
    test "kicks off a task for redownloadable media items" do
      media_profile = media_profile_fixture(%{redownload_delay_days: 4})
      source = source_fixture(%{media_profile_id: media_profile.id, inserted_at: now_minus(10, :days)})

      media_item =
        media_item_fixture(%{
          source_id: source.id,
          upload_date: now_minus(6, :days),
          media_downloaded_at: now_minus(5, :days)
        })

      perform_job(MediaRedownloadWorker, %{})

      assert [_] = all_enqueued(worker: MediaDownloadWorker, args: %{id: media_item.id, redownload?: true})
    end

    test "does not kickoff a task for non-redownloadable media items" do
      media_profile = media_profile_fixture(%{redownload_delay_days: 4})
      source = source_fixture(%{media_profile_id: media_profile.id, inserted_at: now_minus(10, :days)})

      _media_item =
        media_item_fixture(%{
          source_id: source.id,
          upload_date: now_minus(6, :days),
          media_downloaded_at: now_minus(1, :day)
        })

      perform_job(MediaRedownloadWorker, %{})

      assert [] = all_enqueued(worker: MediaDownloadWorker)
    end
  end
end
