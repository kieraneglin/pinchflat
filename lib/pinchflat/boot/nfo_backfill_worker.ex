defmodule Pinchflat.Boot.NfoBackfillWorker do
  @moduledoc false

  use Oban.Worker,
    queue: :local_metadata,
    # This should have it running once _ever_ (until the job is pruned, anyway)
    # NOTE: remove within the next month
    unique: [period: :infinity, states: Oban.Job.states()],
    tags: ["media_item", "media_metadata", "local_metadata", "data_backfill"]

  import Ecto.Query, warn: false
  require Logger

  alias Pinchflat.Repo
  alias Pinchflat.Media
  alias Pinchflat.Media.MediaItem
  alias Pinchflat.Metadata.NfoBuilder
  alias Pinchflat.Metadata.MetadataFileHelpers

  @doc """
  Runs a one-off backfill job to regenerate NFO files for media items that have
  both an NFO file and a metadata file. This is needed because NFO files weren't
  escaping characters properly so we need to regenerate them.

  This job will only run once as long as I remove it before the jobs are pruned in a month.

  Returns :ok
  """
  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    Logger.info("Running NFO backfill worker")

    media_items = get_media_items_to_backfill()

    Enum.each(media_items, fn media_item ->
      nfo_exists = File.exists?(media_item.nfo_filepath)
      metadata_exists = File.exists?(media_item.metadata.metadata_filepath)

      if nfo_exists && metadata_exists do
        Logger.info("NFO and metadata exist for media item #{media_item.id} - proceeding")

        regenerate_nfo_for_media_item(media_item)
      end
    end)

    :ok
  end

  defp get_media_items_to_backfill do
    from(m in MediaItem, where: not is_nil(m.nfo_filepath))
    |> Repo.all()
    |> Repo.preload([:metadata, source: :media_profile])
  end

  defp regenerate_nfo_for_media_item(media_item) do
    case MetadataFileHelpers.read_compressed_metadata(media_item.metadata.metadata_filepath) do
      {:ok, metadata} ->
        Media.update_media_item(media_item, %{
          nfo_filepath: NfoBuilder.build_and_store_for_media_item(media_item.nfo_filepath, metadata)
        })

      _err ->
        Logger.error("Failed to read metadata for media item #{media_item.id}")
    end
  end
end
