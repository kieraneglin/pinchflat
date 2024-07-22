defmodule Pinchflat.Downloading.MediaRetentionWorkerTest do
  use Pinchflat.DataCase

  import Pinchflat.MediaFixtures
  import Pinchflat.SourcesFixtures

  alias Pinchflat.Media
  alias Pinchflat.Downloading.MediaRetentionWorker

  setup do
    stub(UserScriptRunnerMock, :run, fn _event_type, _data -> {:ok, "", 0} end)

    :ok
  end

  describe "perform/1" do
    test "sets deleted media to not re-download" do
      {_source, old_media_item, new_media_item} = prepare_records_for_retention_date()

      perform_job(MediaRetentionWorker, %{})

      refute Repo.reload!(new_media_item).prevent_download
      assert Repo.reload!(old_media_item).prevent_download
    end

    test "sets culled_at timestamp on deleted media" do
      {_source, old_media_item, new_media_item} = prepare_records_for_retention_date()

      perform_job(MediaRetentionWorker, %{})

      refute Repo.reload!(new_media_item).culled_at
      assert Repo.reload!(old_media_item).culled_at
      assert DateTime.diff(now(), Repo.reload!(old_media_item).culled_at) < 1
    end
  end

  describe "perform/1 when testing retention_period-based culling" do
    test "deletes media files that are past their retention date" do
      {_source, old_media_item, new_media_item} = prepare_records_for_retention_date()

      perform_job(MediaRetentionWorker, %{})

      assert File.exists?(new_media_item.media_filepath)
      refute File.exists?(old_media_item.media_filepath)
      assert Repo.reload!(new_media_item).media_filepath
      refute Repo.reload!(old_media_item).media_filepath
    end

    test "sets culled_at and prevent_download" do
      {_source, old_media_item, new_media_item} = prepare_records_for_retention_date()

      perform_job(MediaRetentionWorker, %{})

      refute Repo.reload!(new_media_item).culled_at
      assert Repo.reload!(old_media_item).culled_at
      refute Repo.reload!(new_media_item).prevent_download
      assert Repo.reload!(old_media_item).prevent_download
    end

    test "doesn't cull if the source doesn't have a retention period" do
      {_source, old_media_item, new_media_item} = prepare_records_for_retention_date(nil)

      perform_job(MediaRetentionWorker, %{})

      assert File.exists?(new_media_item.media_filepath)
      assert File.exists?(old_media_item.media_filepath)
      assert Repo.reload!(new_media_item).media_filepath
      assert Repo.reload!(old_media_item).media_filepath

      refute Repo.reload!(new_media_item).culled_at
      refute Repo.reload!(old_media_item).culled_at
    end

    test "doesn't cull media items that have prevent_culling set" do
      {_source, old_media_item, _new_media_item} = prepare_records_for_retention_date()

      Media.update_media_item(old_media_item, %{prevent_culling: true})

      perform_job(MediaRetentionWorker, %{})

      assert File.exists?(old_media_item.media_filepath)
      assert Repo.reload!(old_media_item).media_filepath
      refute Repo.reload!(old_media_item).culled_at
    end

    test "doesn't cull if the media item has no media_filepath" do
      {_source, old_media_item, _new_media_item} = prepare_records_for_retention_date()

      Media.update_media_item(old_media_item, %{media_filepath: nil})

      perform_job(MediaRetentionWorker, %{})

      refute Repo.reload!(old_media_item).culled_at
    end
  end

  describe "perform/1 when testing source cutoff-based culling" do
    test "culls media from before the cutoff date" do
      {_source, old_media_item, new_media_item} = prepare_records_for_source_cutoff_date()

      perform_job(MediaRetentionWorker, %{})

      assert File.exists?(new_media_item.media_filepath)
      refute File.exists?(old_media_item.media_filepath)
      assert Repo.reload!(new_media_item).media_filepath
      refute Repo.reload!(old_media_item).media_filepath
    end

    test "sets culled_at but not prevent_download" do
      {_source, old_media_item, new_media_item} = prepare_records_for_source_cutoff_date()

      perform_job(MediaRetentionWorker, %{})

      refute Repo.reload!(new_media_item).culled_at
      assert Repo.reload!(old_media_item).culled_at
      refute Repo.reload!(new_media_item).prevent_download
      refute Repo.reload!(old_media_item).prevent_download
    end

    test "doesn't cull media if the source doesn't have a cutoff date" do
      {_source, old_media_item, new_media_item} = prepare_records_for_source_cutoff_date(nil)

      perform_job(MediaRetentionWorker, %{})

      assert File.exists?(new_media_item.media_filepath)
      assert File.exists?(old_media_item.media_filepath)
      assert Repo.reload!(new_media_item).media_filepath
      assert Repo.reload!(old_media_item).media_filepath

      refute Repo.reload!(new_media_item).culled_at
      refute Repo.reload!(old_media_item).culled_at
    end

    test "doesn't cull media from on or after the cutoff date" do
      {_source, old_media_item, new_media_item} = prepare_records_for_source_cutoff_date(2)

      Media.update_media_item(old_media_item, %{uploaded_at: now_minus(2, :days)})
      Media.update_media_item(new_media_item, %{uploaded_at: now_minus(1, :day)})

      perform_job(MediaRetentionWorker, %{})

      assert File.exists?(new_media_item.media_filepath)
      assert File.exists?(old_media_item.media_filepath)
      assert Repo.reload!(new_media_item).media_filepath
      assert Repo.reload!(old_media_item).media_filepath

      refute Repo.reload!(new_media_item).culled_at
      refute Repo.reload!(old_media_item).culled_at
    end

    test "doesn't cull media items that have prevent_culling set" do
      {_source, old_media_item, _new_media_item} = prepare_records_for_source_cutoff_date()

      Media.update_media_item(old_media_item, %{prevent_culling: true})

      perform_job(MediaRetentionWorker, %{})

      assert File.exists?(old_media_item.media_filepath)
      assert Repo.reload!(old_media_item).media_filepath
      refute Repo.reload!(old_media_item).culled_at
    end

    test "doesn't cull if the media item has no media_filepath" do
      {_source, old_media_item, _new_media_item} = prepare_records_for_source_cutoff_date()

      Media.update_media_item(old_media_item, %{media_filepath: nil})

      perform_job(MediaRetentionWorker, %{})

      refute Repo.reload!(old_media_item).culled_at
    end
  end

  defp prepare_records_for_retention_date(retention_period_days \\ 2) do
    source = source_fixture(%{retention_period_days: retention_period_days})

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

  defp prepare_records_for_source_cutoff_date(download_cutoff_date_days_ago \\ 2) do
    cutoff_date = if download_cutoff_date_days_ago, do: now_minus(download_cutoff_date_days_ago, :days), else: nil
    source = source_fixture(%{download_cutoff_date: cutoff_date})

    old_media_item =
      media_item_with_attachments(%{
        source_id: source.id,
        uploaded_at: now_minus(3, :days)
      })

    new_media_item =
      media_item_with_attachments(%{
        source_id: source.id,
        uploaded_at: now_minus(1, :day)
      })

    {source, old_media_item, new_media_item}
  end
end
