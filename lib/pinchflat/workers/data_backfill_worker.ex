defmodule Pinchflat.Workers.DataBackfillWorker do
  @moduledoc false

  use Oban.Worker,
    queue: :media_local_metadata,
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

  alias __MODULE__
  alias Pinchflat.Repo
  alias Pinchflat.Media.MediaItem

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
    backfill_shorts_data()

    reschedule_backfill()

    :ok
  end

  defp backfill_shorts_data do
    query =
      from(
        m in MediaItem,
        where: fragment("? like ?", m.original_url, "%/shorts/%"),
        where: m.short_form_content == false
      )

    Repo.update_all(query, set: [short_form_content: true])
  end

  defp reschedule_backfill do
    # Run hourly
    next_run_in = 60 * 60

    %{}
    |> DataBackfillWorker.new(schedule_in: next_run_in)
    |> Repo.insert_unique_job()
  end
end
