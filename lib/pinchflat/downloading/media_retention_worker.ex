defmodule Pinchflat.Downloading.MediaRetentionWorker do
  @moduledoc false

  use Oban.Worker,
    queue: :local_data,
    unique: [period: :infinity, states: [:available, :scheduled, :retryable, :executing]],
    tags: ["media_item", "local_data"]

  use Pinchflat.Media.MediaQuery

  require Logger

  alias Pinchflat.Repo
  alias Pinchflat.Media

  @doc """
  Deletes media items that are past their retention date and prevents
  them from being re-downloaded.

  This worker is scheduled to run daily via the Oban Cron plugin.

  Returns :ok
  """
  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    cull_cullable_media_items()
    delete_media_items_from_before_cutoff()

    :ok
  end

  defp cull_cullable_media_items do
    cullable_media =
      MediaQuery.new()
      |> MediaQuery.require_assoc(:source)
      |> where(^MediaQuery.cullable())
      |> Repo.all()

    Logger.info("Culling #{length(cullable_media)} media items past their retention date")

    Enum.each(cullable_media, fn media_item ->
      # Setting `prevent_download` does what it says on the tin, but `culled_at` is purely informational.
      # We don't actually do anything with that in terms of queries and it gets set to nil if the media item
      # gets re-downloaded.
      Media.delete_media_files(media_item, %{
        prevent_download: true,
        culled_at: DateTime.utc_now()
      })
    end)
  end

  # NOTE: Since this is a date and not a datetime, we can't add logic to have to-the-minute
  # comparison like we can with retention periods. We can only compare to the day.
  defp delete_media_items_from_before_cutoff do
    deletable_media =
      MediaQuery.new()
      |> MediaQuery.require_assoc(:source)
      |> where(^MediaQuery.deletable_based_on_source_cutoff())
      |> Repo.all()

    Logger.info("Deleting #{length(deletable_media)} media items that are from before the source cutoff")

    Enum.each(deletable_media, fn media_item ->
      # Note that I'm not setting `prevent_download` on the media_item here.
      # That's because cutoff_date can easily change and it's a valid behavior to re-download older
      # media items if the cutoff_date changes.
      # Download is ultimately prevented because `MediaQuery.pending()` only returns media items
      # from after the cutoff date (among other things), so it's not like the media will just immediately
      # be re-downloaded.
      Media.delete_media_files(media_item, %{
        culled_at: DateTime.utc_now()
      })
    end)
  end
end
