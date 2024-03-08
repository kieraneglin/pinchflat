defmodule Pinchflat.Workers.MediaIndexingWorker do
  @moduledoc false

  use Oban.Worker,
    queue: :media_indexing,
    unique: [period: :infinity, states: [:available, :scheduled, :retryable]],
    tags: ["media_source", "media_collection_indexing"]

  alias Pinchflat.Sources

  @impl Oban.Worker
  @doc """
  Similar to `MediaCollectionIndexingWorker`, but for individual media items.
  Does not reschedule or check anything to do with a source's indexing
  frequency - only collects initial metadata then kicks off a download.
  `MediaCollectionIndexingWorker` should be preferred in general, but this is
  useful for downloading one-off media items based on a URL (like for fast indexing).

  Only downloads media that _should_ be downloaded (ie: the source is set to download
  and the media matches the profile's format preferences). Splits downloading into
  another job to keep the indexing queue moving quickly.

  Returns :ok
  """

  def perform(%Oban.Job{args: %{"id" => source_id, "media_url" => _media_url}}) do
    _source = Sources.get_source!(source_id)
  end
end
