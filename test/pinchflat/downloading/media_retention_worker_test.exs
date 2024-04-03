defmodule Pinchflat.Downloading.MediaRetentionWorkerTest do
  use Pinchflat.DataCase

  import Pinchflat.MediaFixtures
  import Pinchflat.SourcesFixtures

  alias Pinchflat.Media
  alias Pinchflat.Downloading.MediaRetentionWorker

  describe "perform/1" do
    test "deletes media files that are past their retention date" do
      {_source, old_media_item, new_media_item} = prepare_records()

      perform_job(MediaRetentionWorker, %{})

      assert File.exists?(new_media_item.media_filepath)
      refute File.exists?(old_media_item.media_filepath)
      assert Repo.reload!(new_media_item).media_filepath
      refute Repo.reload!(old_media_item).media_filepath
    end

    test "sets deleted media to not re-download" do
      {_source, old_media_item, new_media_item} = prepare_records()

      perform_job(MediaRetentionWorker, %{})

      refute Repo.reload!(new_media_item).prevent_download
      assert Repo.reload!(old_media_item).prevent_download
    end

    test "sets culled_at timestamp on deleted media" do
      {_source, old_media_item, new_media_item} = prepare_records()

      perform_job(MediaRetentionWorker, %{})

      refute Repo.reload!(new_media_item).culled_at
      assert Repo.reload!(old_media_item).culled_at
      assert DateTime.diff(now(), Repo.reload!(old_media_item).culled_at) < 1
    end

    test "doesn't cull media items that have prevent_culling set" do
      {_source, old_media_item, _new_media_item} = prepare_records()

      Media.update_media_item(old_media_item, %{prevent_culling: true})

      perform_job(MediaRetentionWorker, %{})

      assert File.exists?(old_media_item.media_filepath)
      assert Repo.reload!(old_media_item).media_filepath
    end
  end

  defp prepare_records do
    source = source_fixture(%{retention_period_days: 2})

    old_media_item =
      media_item_with_attachments(%{
        source_id: source.id,
        media_downloaded_at: now_minus(3, :days)
      })

    new_media_item =
      media_item_with_attachments(%{
        source_id: source.id,
        media_downloaded_at: now_minus(1, :day)
      })

    {source, old_media_item, new_media_item}
  end
end
