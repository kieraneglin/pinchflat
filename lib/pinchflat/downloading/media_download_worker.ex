defmodule Pinchflat.Downloading.MediaDownloadWorker do
  @moduledoc false

  use Oban.Worker,
    queue: :media_fetching,
    unique: [period: :infinity, states: [:available, :scheduled, :retryable, :executing]],
    tags: ["media_item", "media_fetching"]

  require Logger

  alias __MODULE__
  alias Pinchflat.Tasks
  alias Pinchflat.Repo
  alias Pinchflat.Media
  alias Pinchflat.Downloading.MediaDownloader

  @doc """
  Starts the media_item media download worker and creates a task for the media_item.

  Returns {:ok, %Task{}} | {:error, :duplicate_job} | {:error, %Ecto.Changeset{}}
  """
  def kickoff_with_task(media_item, opts \\ []) do
    %{id: media_item.id}
    |> MediaDownloadWorker.new(opts)
    |> Tasks.create_job_with_task(media_item)
  end

  @doc """
  For a given media item, download the media alongside any options.
  Does not download media if its source is set to not download media.

  Returns :ok | {:ok, %MediaItem{}} | {:error, any, ...any}
  """
  @impl Oban.Worker
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
  rescue
    Ecto.NoResultsError -> Logger.info("#{__MODULE__} discarded: media item #{media_item_id} not found")
    Ecto.StaleEntryError -> Logger.info("#{__MODULE__} discarded: media item #{media_item_id} stale")
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
