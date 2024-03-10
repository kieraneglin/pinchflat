defmodule Pinchflat.Workers.MediaCollectionIndexingWorker do
  @moduledoc false

  use Oban.Worker,
    queue: :media_collection_indexing,
    unique: [period: :infinity, states: [:available, :scheduled, :retryable]],
    tags: ["media_source", "media_collection_indexing"]

  alias __MODULE__
  alias Pinchflat.Tasks
  alias Pinchflat.Sources
  alias Pinchflat.Sources.Source
  alias Pinchflat.Tasks.SourceTasks
  alias Pinchflat.Workers.FastIndexingWorker

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

  Order of operations:
    1. The user saves a source
    2. This job is automatically scheduled immediately. This happens in all cases.
    3. This job indexes all content for the given source. A download job is
       enqueued for each media item that should be downloaded. This can be impacted
       by the `download_media` field on the source as well as the profile's
       shorts/livestream behaviour. At this step we also attach a file reader
       to the `yt-dlp` output file so we can create media items as they come in
       for a little speedup (see SourceTasks comments for more)
    4. If this job is meant to reschedule (ie: has an index frequency > 0),
       it reschedules itself. If not, it runs once and does not reschedule
    5. If the source uses fast indexing, that job is kicked off as well. It
       uses RSS to run a smaller, faster, and more frequent index. That job
       handles rescheduling itself but largely has a similar behaviour to this
       job in that it kicks off index and maybe download jobs. The biggest difference
       is that an index job is kicked off _for each new media item_ as opposed
       to one larger index job. Check out `MediaIndexingWorker` comments for more.
    6. If the job reschedules, the cycle from step 3 repeats until the heat death
       of the universe. The user changing things like the index frequency can
       dequeue or reschedule jobs as well

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
        SourceTasks.index_and_enqueue_download_for_media_items(source)
        maybe_enqueue_fast_indexing_task(source)
        reschedule_indexing(source)

      {_, nil} ->
        # If the source has never been indexed, index it once
        # even if it's not meant to reschedule
        SourceTasks.index_and_enqueue_download_for_media_items(source)
        :ok

      _ ->
        # If the source HAS been indexed and is not meant to reschedule,
        # perform a no-op
        :ok
    end
  end

  defp reschedule_indexing(source) do
    next_run_in = source.index_frequency_minutes * 60

    %{id: source.id}
    |> MediaCollectionIndexingWorker.new(schedule_in: next_run_in)
    |> Tasks.create_job_with_task(source)
    |> case do
      {:ok, task} -> {:ok, task}
      {:error, :duplicate_job} -> {:ok, :job_exists}
    end
  end

  defp maybe_enqueue_fast_indexing_task(source) do
    if source.fast_index do
      Tasks.delete_pending_tasks_for(source, "FastIndexingWorker")

      next_run_in = Source.fast_index_frequency() * 60

      %{id: source.id}
      |> FastIndexingWorker.new(schedule_in: next_run_in)
      |> Tasks.create_job_with_task(source)
    end
  end
end
