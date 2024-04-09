defmodule Pinchflat.Downloading.MediaRedownloadWorker do
  @moduledoc false

  use Oban.Worker,
    queue: :media_fetching,
    unique: [period: :infinity, states: [:available, :scheduled, :retryable, :executing]],
    tags: ["media_item", "media_fetching"]

  require Logger

  alias Pinchflat.Media

  @doc """
  """
  # TODO
  @impl Oban.Worker
  def perform(%Oban.Job{}) do
  end
end
