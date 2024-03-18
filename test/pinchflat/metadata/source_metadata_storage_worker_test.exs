defmodule Pinchflat.Metadata.SourceMetadataStorageWorkerTest do
  use Pinchflat.DataCase
  import Mox
  import Pinchflat.SourcesFixtures

  alias Pinchflat.Metadata.MetadataFileHelpers
  alias Pinchflat.Metadata.SourceMetadataStorageWorker

  @source_details_ot "%(.{channel,channel_id,playlist_id,playlist_title,filename})j"
  @metadata_ot "playlist:%()j"

  setup :verify_on_exit!

  describe "kickoff_with_task/1" do
    test "enqueues a new worker for the source" do
      source = source_fixture()

      assert {:ok, _} = SourceMetadataStorageWorker.kickoff_with_task(source)

      assert_enqueued(worker: SourceMetadataStorageWorker, args: %{"id" => source.id})
    end

    test "creates a new task for the source" do
      source = source_fixture()

      assert {:ok, task} = SourceMetadataStorageWorker.kickoff_with_task(source)

      assert task.source_id == source.id
    end
  end

  describe "perform/1" do
    test "won't call itself in an infinite loop" do
      stub(YtDlpRunnerMock, :run, fn
        _url, _opts, ot when ot == @source_details_ot -> {:ok, source_details_return_fixture()}
        _url, _opts, ot when ot == @metadata_ot -> {:ok, "{}"}
      end)

      source = source_fixture()

      perform_job(SourceMetadataStorageWorker, %{id: source.id})
      perform_job(SourceMetadataStorageWorker, %{id: source.id})

      assert [_] = all_enqueued(worker: SourceMetadataStorageWorker)
    end

    test "doesn't prevent over source jobs from running" do
      stub(YtDlpRunnerMock, :run, fn
        _url, _opts, ot when ot == @source_details_ot -> {:ok, source_details_return_fixture()}
        _url, _opts, ot when ot == @metadata_ot -> {:ok, "{}"}
      end)

      source_1 = source_fixture()
      source_2 = source_fixture()

      perform_job(SourceMetadataStorageWorker, %{id: source_1.id})
      perform_job(SourceMetadataStorageWorker, %{id: source_1.id})
      perform_job(SourceMetadataStorageWorker, %{id: source_2.id})
      perform_job(SourceMetadataStorageWorker, %{id: source_2.id})

      assert [_, _] = all_enqueued(worker: SourceMetadataStorageWorker)
    end

    test "does not blow up if the record doesn't exist" do
      assert :ok = perform_job(SourceMetadataStorageWorker, %{id: 0})
    end
  end

  describe "perform/1 when testing metadata storage" do
    test "sets metadata location for source" do
      stub(YtDlpRunnerMock, :run, fn
        _url, _opts, ot when ot == @source_details_ot -> {:ok, source_details_return_fixture()}
        _url, _opts, ot when ot == @metadata_ot -> {:ok, "{}"}
      end)

      source = Repo.preload(source_fixture(), :metadata)

      refute source.metadata
      perform_job(SourceMetadataStorageWorker, %{id: source.id})
      source = Repo.preload(Repo.reload(source), :metadata)

      assert source.metadata.metadata_filepath

      File.rm!(source.metadata.metadata_filepath)
    end

    test "fetches and stores returned metadata for source" do
      source = source_fixture()
      file_contents = Phoenix.json_library().encode!(%{"title" => "test"})

      stub(YtDlpRunnerMock, :run, fn
        _url, _opts, ot when ot == @source_details_ot -> {:ok, source_details_return_fixture()}
        _url, _opts, ot when ot == @metadata_ot -> {:ok, file_contents}
      end)

      perform_job(SourceMetadataStorageWorker, %{id: source.id})
      source = Repo.preload(Repo.reload(source), :metadata)
      {:ok, metadata} = MetadataFileHelpers.read_compressed_metadata(source.metadata.metadata_filepath)

      assert metadata == %{"title" => "test"}
    end
  end

  describe "perform/1 when determining the series_directory" do
    test "sets the series directory based on the returned media filepath" do
      stub(YtDlpRunnerMock, :run, fn
        _url, _opts, ot when ot == @source_details_ot ->
          filename = Path.join([Application.get_env(:pinchflat, :media_directory), "Season 1", "bar.mp4"])

          {:ok, source_details_return_fixture(%{filename: filename})}

        _url, _opts, ot when ot == @metadata_ot ->
          {:ok, "{}"}
      end)

      source = source_fixture(%{series_directory: nil})
      perform_job(SourceMetadataStorageWorker, %{id: source.id})
      source = Repo.reload(source)

      assert source.series_directory
    end

    test "does not set the series directory if it cannot be determined" do
      stub(YtDlpRunnerMock, :run, fn
        _url, _opts, ot when ot == @source_details_ot ->
          filename = Path.join([Application.get_env(:pinchflat, :media_directory), "foo", "bar.mp4"])

          {:ok, source_details_return_fixture(%{filename: filename})}

        _url, _opts, ot when ot == @metadata_ot ->
          {:ok, "{}"}
      end)

      source = source_fixture(%{series_directory: nil})
      perform_job(SourceMetadataStorageWorker, %{id: source.id})
      source = Repo.reload(source)

      refute source.series_directory
    end
  end
end
