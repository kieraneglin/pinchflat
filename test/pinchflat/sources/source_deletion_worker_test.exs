defmodule Pinchflat.Sources.SourceDeletionWorkerTest do
  use Pinchflat.DataCase

  import Pinchflat.MediaFixtures
  import Pinchflat.SourcesFixtures

  alias Pinchflat.Sources.SourceDeletionWorker

  setup do
    stub(UserScriptRunnerMock, :run, fn _event_type, _data -> :ok end)

    {:ok, %{source: source_fixture()}}
  end

  describe "kickoff/3" do
    test "starts the worker", %{source: source} do
      assert [] = all_enqueued(worker: SourceDeletionWorker)
      assert {:ok, _} = SourceDeletionWorker.kickoff(source)
      assert [_] = all_enqueued(worker: SourceDeletionWorker)
    end

    test "can be called with additional job arguments", %{source: source} do
      job_args = %{"delete_files" => true}

      assert {:ok, _} = SourceDeletionWorker.kickoff(source, job_args)

      assert_enqueued(worker: SourceDeletionWorker, args: %{"id" => source.id, "delete_files" => true})
    end
  end

  describe "perform/1" do
    test "deletes the source but leaves the files", %{source: source} do
      media_item = media_item_with_attachments(%{source_id: source.id})

      perform_job(SourceDeletionWorker, %{"id" => source.id})

      assert_raise Ecto.NoResultsError, fn -> Repo.reload!(source) end
      assert_raise Ecto.NoResultsError, fn -> Repo.reload!(media_item) end
      assert File.exists?(media_item.media_filepath)
    end

    test "deletes the source and files if specified", %{source: source} do
      media_item = media_item_with_attachments(%{source_id: source.id})

      perform_job(SourceDeletionWorker, %{"id" => source.id, "delete_files" => true})

      assert_raise Ecto.NoResultsError, fn -> Repo.reload!(source) end
      assert_raise Ecto.NoResultsError, fn -> Repo.reload!(media_item) end
      refute File.exists?(media_item.media_filepath)
    end
  end
end
