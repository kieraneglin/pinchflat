defmodule Pinchflat.Workers.MediaIndexingWorker do
  @moduledoc false

  use Oban.Worker,
    queue: :media_indexing,
    unique: [period: :infinity, states: [:available, :scheduled]]

  alias __MODULE__
  alias Pinchflat.MediaSource

  @impl Oban.Worker
  @doc """
  The ID is that of a channel _record_, not a YouTube channel ID.

  NOTE: Re-scheduling here works a little different than you may expect.
  The reschedule time is relative to the time the job has actually _completed_.
  This has some benefits but also side effects to be aware of:

  - Benefit: No chance for jobs to overlap if a job takes longer than the
    scheduled interval. Less likely to hit API rate limits.
  - Side effect: Intervals are "soft" and _always_ walk forward. This may cause
    user confusion since a 30-minute job scheduled for every hour will
    actually run every 1 hour and 30 minutes. The tradeoff of not inundating
    the API with requests and also not overlapping jobs is worth it, IMO.

  Returns :ok | {:ok, %Oban.Job{}}. Not that it matters.
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

    channel
    |> Map.take([:id])
    |> MediaIndexingWorker.new(schedule_in: channel.index_frequency_minutes * 60)
    |> Oban.insert()
  end
end
