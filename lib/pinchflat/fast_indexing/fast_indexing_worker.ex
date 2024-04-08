defmodule Pinchflat.FastIndexing.FastIndexingWorker do
  @moduledoc false

  use Oban.Worker,
    queue: :fast_indexing,
    unique: [period: :infinity, states: [:available, :scheduled, :retryable]],
    tags: ["media_source", "fast_indexing"]

  require Logger

  alias __MODULE__
  alias Pinchflat.Tasks
  alias Pinchflat.Sources
  alias Pinchflat.Settings
  alias Pinchflat.Sources.Source
  alias Pinchflat.FastIndexing.FastIndexingHelpers
  alias Pinchflat.Notifications.SourceNotifications

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
  Kicks off the fast indexing process for a source, reschedules the job to run again
  once complete. See `MediaCollectionIndexingWorker` and `MediaIndexingWorker` comments
  for more

  Returns :ok | {:ok, :job_exists} | {:ok, %Task{}}
  """
  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"id" => source_id}}) do
    source = Sources.get_source!(source_id)

    if source.fast_index do
      perform_indexing_and_notification(source)
      reschedule_indexing(source)
    else
      :ok
    end
  rescue
    Ecto.NoResultsError -> Logger.info("#{__MODULE__} discarded: source #{source_id} not found")
    Ecto.StaleEntryError -> Logger.info("#{__MODULE__} discarded: source #{source_id} stale")
  end

  defp perform_indexing_and_notification(source) do
    apprise_server = Settings.get!(:apprise_server)
    new_media_items = FastIndexingHelpers.kickoff_indexing_tasks_from_youtube_rss_feed(source)

    SourceNotifications.send_new_media_notification(apprise_server, source, length(new_media_items))
  end

  defp reschedule_indexing(source) do
    next_run_in = Source.fast_index_frequency() * 60

    case kickoff_with_task(source, schedule_in: next_run_in) do
      {:ok, task} -> {:ok, task}
      {:error, :duplicate_job} -> {:ok, :job_exists}
    end
  end
end
