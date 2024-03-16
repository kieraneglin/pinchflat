defmodule Pinchflat.FastIndexing.MediaIndexingWorker do
  @moduledoc false

  use Oban.Worker,
    queue: :media_indexing,
    unique: [period: :infinity, states: [:available, :scheduled, :retryable]],
    tags: ["media_source", "media_indexing"]

  require Logger

  alias __MODULE__
  alias Pinchflat.Tasks
  alias Pinchflat.Sources
  alias Pinchflat.FastIndexing.FastIndexingHelpers

  @doc """
  Starts the fast media indexing worker and creates a task for the source.

  Returns {:ok, %Task{}} | {:error, :duplicate_job} | {:error, %Ecto.Changeset{}}
  """
  def kickoff_with_task(source, media_url, opts \\ []) do
    %{id: source.id, media_url: media_url}
    |> MediaIndexingWorker.new(opts)
    |> Tasks.create_job_with_task(source)
  end

  @doc """
  Similar to `MediaCollectionIndexingWorker`, but for individual media items.
  Does not reschedule or check anything to do with a source's indexing
  frequency - only collects initial metadata then kicks off a download.
  `MediaCollectionIndexingWorker` should be preferred in general, but this is
  useful for downloading one-off media items based on a URL (like for fast indexing).

  Only downloads media that _should_ be downloaded (ie: the source is set to download
  and the media matches the profile's format preferences)

  Order of operations:
    1. FastIndexingHelpers.kickoff_indexing_tasks_from_youtube_rss_feed/1 (which is running
       in its own worker) periodically checks the YouTube RSS feed for new media
    2. If new media is found, it enqueues a MediaIndexingWorker (this module) for each new media
       item
    3. This worker fetches the media metadata and uses that to determine if it should be
       downloaded. If so, it enqueues a MediaDownloadWorker

  Each is a worker because they all either need to be scheduled periodically or call out to
  an external service and will be long-running. They're split into different jobs to separate
  retry logic for each step and allow us to better optimize various queues (eg: the indexing
  steps can keep running while the slow download steps are worked through).

  Returns :ok
  """
  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"id" => source_id, "media_url" => media_url}}) do
    source = Sources.get_source!(source_id)

    case FastIndexingHelpers.index_and_enqueue_download_for_media_item(source, media_url) do
      {:ok, media_item} ->
        Logger.debug("Indexed and enqueued download for url: #{media_url} (media item: #{media_item.id})")

      {:error, reason} ->
        Logger.debug("Failed to index and enqueue download for url: #{media_url} (reason: #{inspect(reason)})")
    end

    :ok
  rescue
    Ecto.NoResultsError -> Logger.info("#{__MODULE__} discarded: source #{source_id} not found")
    Ecto.StaleEntryError -> Logger.info("#{__MODULE__} discarded: source #{source_id} stale")
  end
end
