defmodule Pinchflat.Boot.DataBackfillWorker do
  @moduledoc false

  use Oban.Worker,
    queue: :local_metadata,
    unique: [period: :infinity, states: [:available, :scheduled, :retryable]],
    tags: ["media_item", "media_metadata", "local_metadata", "data_backfill"]

  # This one is going to be a little more self-contained
  # instead of relying on outside modules for the methods.
  # That's because, for now, these methods are not intended
  # to be used elsewhere.
  #
  # I'm just trying out that pattern and seeing if I like it better
  # so this may change.
  import Ecto.Query, warn: false
  require Logger

  alias __MODULE__
  alias Pinchflat.Repo

  @doc """
  Cancels all pending backfill jobs. Useful for ensuring worker runs immediately
  on app boot.

  Returns {:ok, integer()}
  """
  def cancel_pending_backfill_jobs do
    Oban.Job
    |> where(worker: "Pinchflat.Boot.DataBackfillWorker")
    |> Oban.cancel_all_jobs()
  end

  @impl Oban.Worker
  @doc """
  Performs one-off tasks to get data in the right shape.
  This can be needed when we add new features or change the way
  we store data. Must be idempotent. All new data should already
  conform to the expected schema so this should only be needed
  for existing data. Still runs periodically to be safe.

  Returns :ok
  """
  def perform(%Oban.Job{}) do
    Logger.info("Running data backfill worker")
    # Nothing to do for now - just reschedule
    # Keeping in-place because we _will_ need it in the future

    reschedule_backfill()

    :ok
  end

  defp reschedule_backfill do
    # Run hourly
    next_run_in = 60 * 60

    %{}
    |> DataBackfillWorker.new(schedule_in: next_run_in)
    |> Repo.insert_unique_job()
  end
end
