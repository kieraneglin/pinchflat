defmodule Pinchflat.Downloading.MediaDownloadWorker do
  @moduledoc false

  use Oban.Worker,
    queue: :media_fetching,
    unique: [period: :infinity, states: [:available, :scheduled, :retryable, :executing]],
    tags: ["media_item", "media_fetching"]

  alias Pinchflat.Repo
  alias Pinchflat.Media
  alias Pinchflat.Downloading.MediaDownloader

  @impl Oban.Worker
  @doc """
  For a given media item, download the media alongside any options.
  Does not download media if its source is set to not download media.

  Returns :ok | {:ok, %MediaItem{}} | {:error, any, ...any}
  """
  def perform(%Oban.Job{args: %{"id" => media_item_id}}) do
    media_item =
      media_item_id
      |> Media.get_media_item!()
      |> Repo.preload(:source)

    # If the source is set to not download media, perform a no-op
    if media_item.source.download_media do
      download_media_and_schedule_jobs(media_item)
    else
      :ok
    end
  end

  defp download_media_and_schedule_jobs(media_item) do
    case MediaDownloader.download_for_media_item(media_item) do
      {:ok, updated_media_item} ->
        compute_and_save_media_filesize(updated_media_item)

        {:ok, updated_media_item}

      err ->
        err
    end
  end

  defp compute_and_save_media_filesize(media_item) do
    case File.stat(media_item.media_filepath) do
      {:ok, %{size: size}} ->
        Media.update_media_item(media_item, %{media_size_bytes: size})

      _ ->
        :ok
    end
  end
end
