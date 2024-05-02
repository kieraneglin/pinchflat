defmodule Pinchflat.FastIndexing.FastIndexingWorker do
  @moduledoc false

  use Oban.Worker,
    queue: :fast_indexing,
    unique: [period: :infinity, states: [:available, :scheduled, :retryable]],
    tags: ["media_source", "fast_indexing"]

  require Logger

  alias __MODULE__
  alias Pinchflat.Tasks
  alias Pinchflat.Media
  alias Pinchflat.Sources
  alias Pinchflat.Settings
  alias Pinchflat.Sources.Source
  alias Pinchflat.FastIndexing.FastIndexingHelpers
  alias Pinchflat.Lifecycle.Notifications.SourceNotifications

  @doc """
  Starts the source fast indexing worker and creates a task for the source.

  Returns {:ok, %Task{}} | {:error, :duplicate_job} | {:error, %Ecto.Changeset{}}
  """
  def kickoff_with_task(source, opts \\ []) do
    %{id: source.id}
    |> FastIndexingWorker.new(opts)
    |> Tasks.create_job_with_task(source)
  end

  @doc """
  Similar to `MediaCollectionIndexingWorker`, but for working with RSS feeds.
  `MediaCollectionIndexingWorker` should be preferred in general, but this is
  useful for downloading small batches of media items via fast indexing.

  Only kicks off downloads for media that _should_ be downloaded
  (ie: the source is set to download and the media matches the profile's format preferences)

  Order of operations:
    1. FastIndexingWorker (this module) periodically checks the YouTube RSS feed for new media.
       with `FastIndexingHelpers.kickoff_download_tasks_from_youtube_rss_feed`
    2. If the above `kickoff_download_tasks_from_youtube_rss_feed` finds new media items in the RSS feed,
       it indexes them with a yt-dlp call to create the media item records then kicks off downloading
       tasks (MediaDownloadWorker) for any new media items _that should be downloaded_.
    3. Once downloads are kicked off, this worker sends a notification to the apprise server if applicable
       then reschedules itself to run again in the future.

  Returns :ok | {:ok, :job_exists} | {:ok, %Task{}}
  """
  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"id" => source_id}}) do
    source = Sources.get_source!(source_id)

    if source.fast_index do
      perform_indexing_and_send_notification(source)
      reschedule_indexing(source)
    else
      :ok
    end
  rescue
    Ecto.NoResultsError -> Logger.info("#{__MODULE__} discarded: source #{source_id} not found")
    Ecto.StaleEntryError -> Logger.info("#{__MODULE__} discarded: source #{source_id} stale")
  end

  defp perform_indexing_and_send_notification(source) do
    apprise_server = Settings.get!(:apprise_server)

    new_media_items =
      source
      |> FastIndexingHelpers.kickoff_download_tasks_from_youtube_rss_feed()
      |> Enum.filter(&Media.pending_download?(&1))

    if source.download_media do
      SourceNotifications.send_new_media_notification(apprise_server, source, length(new_media_items))
    end
  end

  defp reschedule_indexing(source) do
    next_run_in = Source.fast_index_frequency() * 60

    case kickoff_with_task(source, schedule_in: next_run_in) do
      {:ok, task} -> {:ok, task}
      {:error, :duplicate_job} -> {:ok, :job_exists}
    end
  end
end
