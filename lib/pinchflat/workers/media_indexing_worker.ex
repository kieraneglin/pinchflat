defmodule Pinchflat.Workers.MediaIndexingWorker do
  use Oban.Worker, queue: :media_indexing

  alias Pinchflat.MediaSource

  @impl Oban.Worker
  # This `channel_id` is the ID of the channel _record_ in
  # the database, not the ID of the channel on YouTube.
  # TODO: test
  def perform(%Oban.Job{args: %{"channel_id" => channel_id}}) do
    channel_id
    |> MediaSource.get_channel!()
    |> MediaSource.index_media_items()

    :ok
  end
end
