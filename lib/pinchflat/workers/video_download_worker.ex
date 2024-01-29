defmodule Pinchflat.Workers.VideoDownloadWorker do
  @moduledoc false

  use Oban.Worker,
    queue: :media_fetching,
    unique: [period: :infinity, states: [:available, :scheduled, :retryable]],
    tags: ["media_itwm", "media_fetching"]

  alias Pinchflat.Media
  alias Pinchflat.MediaClient.VideoDownloader

  @impl Oban.Worker
  @doc """
  TODO: test
  """
  def perform(%Oban.Job{args: %{"id" => media_item_id}}) do
    media_item = Media.get_media_item!(media_item_id)

    case VideoDownloader.download_for_media_item(media_item) do
      {:ok, _} ->
        {:ok, media_item}

      err ->
        err
    end
  end
end
