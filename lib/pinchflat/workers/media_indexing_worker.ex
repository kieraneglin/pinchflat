defmodule Pinchflat.Workers.MediaIndexingWorker do
  @moduledoc false

  use Oban.Worker,
    queue: :media_indexing,
    unique: [period: :infinity, states: [:available, :scheduled, :retryable]],
    tags: ["media_source", "media_indexing"]

  alias __MODULE__
  alias Pinchflat.Media
  alias Pinchflat.Tasks
  alias Pinchflat.MediaSource
  alias Pinchflat.Workers.VideoDownloadWorker

  @impl Oban.Worker
  @doc """
  The ID is that of a channel _record_, not a YouTube channel ID. Indexes
  the provided channel, kicks off downloads for each new MediaItem, and
  reschedules the job to run again in the future (as determined by the
  channel's `index_frequency_minutes` field).

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
  def perform(%Oban.Job{args: %{"id" => channel_id}}) do
    channel = MediaSource.get_channel!(channel_id)

    if channel.index_frequency_minutes <= 0 do
      :ok
    else
      index_media_and_reschedule(channel)
    end
  end

  defp index_media_and_reschedule(channel) do
    MediaSource.index_media_items(channel)
    enqueue_video_downloads(channel)

    channel
    |> Map.take([:id])
    |> MediaIndexingWorker.new(schedule_in: channel.index_frequency_minutes * 60)
    |> Tasks.create_job_with_task(channel)
    |> case do
      {:ok, task} -> {:ok, task}
      {:error, :duplicate_job} -> {:ok, :job_exists}
    end
  end

  # NOTE: this starts a download for each media item that is pending,
  # not just the ones that were indexed in this job run. This should ensure
  # that any stragglers are caught if, for some reason, they weren't enqueued
  # or somehow got de-queued.
  #
  # I'm not sure of a case where this would happen, but it's cheap insurance.
  defp enqueue_video_downloads(channel) do
    channel
    |> Media.list_pending_media_items_for()
    |> Enum.each(fn media_item ->
      media_item
      |> Map.take([:id])
      |> VideoDownloadWorker.new()
      |> Tasks.create_job_with_task(media_item)
    end)
  end
end
