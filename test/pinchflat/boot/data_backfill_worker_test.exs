defmodule Pinchflat.Boot.DataBackfillWorkerTest do
  use Pinchflat.DataCase

  alias Pinchflat.Boot.DataBackfillWorker
  alias Pinchflat.JobFixtures.TestJobWorker

  describe "cancel_pending_backfill_jobs/0" do
    test "cancels all pending backfill jobs" do
      %{}
      |> DataBackfillWorker.new()
      |> Repo.insert_unique_job()

      assert_enqueued(worker: DataBackfillWorker)

      DataBackfillWorker.cancel_pending_backfill_jobs()

      refute_enqueued(worker: DataBackfillWorker)
    end

    test "does not cancel jobs for other workers" do
      %{id: 0}
      |> TestJobWorker.new()
      |> Repo.insert_unique_job()

      assert_enqueued(worker: TestJobWorker)

      DataBackfillWorker.cancel_pending_backfill_jobs()

      assert_enqueued(worker: TestJobWorker)
    end
  end

  describe "perform/1" do
    setup do
      DataBackfillWorker.cancel_pending_backfill_jobs()

      :ok
    end

    test "reschedules itself once complete" do
      perform_job(DataBackfillWorker, %{})

      assert_enqueued(worker: DataBackfillWorker, scheduled_at: now_plus(60, :minutes))
    end
  end
end
