defmodule Pinchflat.Downloading.MediaRetentionWorker do
  @moduledoc false

  use Oban.Worker,
    queue: :local_metadata,
    unique: [period: :infinity, states: [:available, :scheduled, :retryable, :executing]],
    tags: ["media_item", "local_metadata"]

  require Logger

  alias Pinchflat.Media

  # TODO: update wiki after this is merged
  # TODO: remove data backfill worker
  # TODO: (other PR - not this one) add way to manually trigger an index of a source AND a pending media download
  # of a source
  @doc """
  Deletes media items that are past their retention date and prevents
  them from being re-downloaded.

  This worker is scheduled to run daily via the Oban Cron plugin.

  Returns :ok
  """
  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    cullable_media = Media.list_cullable_media_items()
    Logger.info("Culling #{length(cullable_media)} media items past their retention date")

    Enum.each(cullable_media, fn media_item ->
      Media.delete_media_files(media_item, %{
        prevent_download: true,
        culled_at: DateTime.utc_now()
      })
    end)
  end
end
