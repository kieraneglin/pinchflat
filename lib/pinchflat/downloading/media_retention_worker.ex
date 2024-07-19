defmodule Pinchflat.Downloading.MediaRetentionWorker do
  @moduledoc false

  use Oban.Worker,
    queue: :local_metadata,
    unique: [period: :infinity, states: [:available, :scheduled, :retryable, :executing]],
    tags: ["media_item", "local_metadata"]

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
    # delete_media_items_from_before_cutoff()

    :ok
  end

  defp cull_cullable_media_items do
    # TODO: consider bringing `list_cullable_media_items` into this module since it's only used here
    cullable_media = Media.list_cullable_media_items()
    Logger.info("Culling #{length(cullable_media)} media items past their retention date")

    Enum.each(cullable_media, fn media_item ->
      # Setting `prevent_download` does what it says on the tin,
      # TODO: finish these docs
      Media.delete_media_files(media_item, %{
        prevent_download: true,
        culled_at: DateTime.utc_now()
      })
    end)
  end

  # TODO: test
  defp delete_media_items_from_before_cutoff do
    deletable_media =
      MediaQuery.new()
      |> MediaQuery.require_assoc(:source)
      |> where(^MediaQuery.deletable_from_source_cutoff())
      |> Repo.all()

    Logger.info("Deleting #{length(deletable_media)} media items that are from before the source cutoff")
    # TODO: Maybe I should be setting `culled_at` here since it does capture what's actually happening.
    # There are also a few spots in code that check for `culled_at` to determine if a media item is
    # eligible for redownload, for instance. I should re-evalute what `culled_at` actually "means" and,
    # since culled_at really only gets set for items that we prevent download on OR items that shouldn't
    # be redownloaded anyway, maybe it should become purely informational rather than functional.
    #
    # TODO: depending on the above, maybe I should ensure that `culled_at` is set to nil if the media item
    # gets re-downloaded. Because in this case the user could just change the cutoff date and re-download
    # and I don't think it makes sense to still indicate that the media item was culled.
    Enum.each(deletable_media, fn media_item ->
      # Note that I'm not setting any attributes like `prevent_download` on the media_item here.
      # That's because cutoff_date can easily change and it's a valid behavior to re-download older
      # media items if the cutoff_date changes.
      # Download is ultimately prevented because `MediaQuery.pending()` only returns media items
      # from after the cutoff date (among other things).
      Media.delete_media_files(media_item)
    end)
  end
end
