defmodule Pinchflat.Downloading.MediaRetentionWorker do
  @moduledoc false

  use Oban.Worker,
    queue: :local_metadata,
    unique: [period: :infinity, states: [:available, :scheduled, :retryable, :executing]],
    tags: ["media_item", "local_metadata"]

  require Logger

  # TODO: docs
  # TODO: test
  # TODO: set to a 1 min interval to make sure that cron works
  # TODO: update wiki after this is merged
  # TODO: remove data backfill worker
  # TODO: (other PR - not this one) add way to manually trigger an index of a source AND a pending media download
  # of a source
  @impl Oban.Worker
  def perform(%Oban.Job{}) do
  end
end
