defmodule Pinchflat.Metadata.SourceMetadataStorageWorkerTest do
  use Pinchflat.DataCase
  import Mox
  import Pinchflat.SourcesFixtures

  alias Pinchflat.Metadata.MetadataFileHelpers
  alias Pinchflat.Metadata.SourceMetadataStorageWorker

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
    test "sets metadata location for source" do
      expect(YtDlpRunnerMock, :run, fn _url, _opts, _ot -> {:ok, "{}"} end)
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
      expect(YtDlpRunnerMock, :run, fn _url, _opts, _ot -> {:ok, file_contents} end)

      perform_job(SourceMetadataStorageWorker, %{id: source.id})
      source = Repo.preload(Repo.reload(source), :metadata)
      {:ok, metadata} = MetadataFileHelpers.read_compressed_metadata(source.metadata.metadata_filepath)

      assert metadata == %{"title" => "test"}
    end

    test "won't call itself in an infinite loop" do
      stub(YtDlpRunnerMock, :run, fn _url, _opts, _ot -> {:ok, "{}"} end)
      source = source_fixture()

      perform_job(SourceMetadataStorageWorker, %{id: source.id})
      perform_job(SourceMetadataStorageWorker, %{id: source.id})

      assert [_] = all_enqueued(worker: SourceMetadataStorageWorker)
    end

    test "doesn't prevent over source jobs from running" do
      stub(YtDlpRunnerMock, :run, fn _url, _opts, _ot -> {:ok, "{}"} end)
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
end
