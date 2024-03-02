defmodule Pinchflat.Workers.MediaIndexingWorker do
  @moduledoc false

  use Oban.Worker,
    queue: :media_indexing,
    unique: [period: :infinity, states: [:available, :scheduled, :retryable]],
    tags: ["media_source", "media_indexing"]

  alias __MODULE__
  alias Pinchflat.Tasks
  alias Pinchflat.Sources
  alias Pinchflat.Tasks.SourceTasks

  @impl Oban.Worker
  @doc """
  The ID is that of a source _record_, not a YouTube channel/playlist ID. Indexes
  the provided source, kicks off downloads for each new MediaItem, and
  reschedules the job to run again in the future. It will ALWAYS index a source
  if it's never been indexed before, but rescheduling is determined by the
  `index_frequency_minutes` field.

  README: Re-scheduling here works a little different than you may expect.
  The reschedule time is relative to the time the job has actually _completed_.
  This has some benefits but also side effects to be aware of:

  - Benefit: No chance for jobs to overlap if a job takes longer than the
    scheduled interval. Less likely to hit API rate limits.
  - Side effect: Intervals are "soft" and _always_ walk forward. This may cause
    user confusion since a 30-minute job scheduled for every hour will
    actually run every 1 hour and 30 minutes. The tradeoff of not inundating
    the API with requests and also not overlapping jobs is worth it, IMO.

  NOTE: Since indexing can take a LONG time, I should check what happens if an
  application restart occurs while a job is running. Will the job be lost?

  IDEA: Should I use paging and do indexing in chunks? Is that even faster?

  Returns :ok | {:ok, %Task{}}
  """
  def perform(%Oban.Job{args: %{"id" => source_id}}) do
    source = Sources.get_source!(source_id)

    case {source.index_frequency_minutes, source.last_indexed_at} do
      {index_freq, _} when index_freq > 0 ->
        # If the indexing is on a schedule simply run indexing and reschedule
        index_media(source)
        reschedule_indexing(source)

      {_, nil} ->
        # If the source has never been indexed, index it once
        # even if it's not meant to reschedule
        index_media(source)

      _ ->
        # If the source HAS been indexed and is not meant to reschedule,
        # perform a no-op
        :ok
    end
  end

  defp index_media(source) do
    SourceTasks.index_media_items(source)
    # This method handles the case where a source is set to not download media
    SourceTasks.enqueue_pending_media_tasks(source)
  end

  defp reschedule_indexing(source) do
    source
    |> Map.take([:id])
    |> MediaIndexingWorker.new(schedule_in: source.index_frequency_minutes * 60)
    |> Tasks.create_job_with_task(source)
    |> case do
      {:ok, task} -> {:ok, task}
      {:error, :duplicate_job} -> {:ok, :job_exists}
    end
  end
end
