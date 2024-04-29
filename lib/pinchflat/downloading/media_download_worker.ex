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
  def kickoff_with_task(media_item, job_args \\ %{}, job_opts \\ []) do
    %{id: media_item.id}
    |> Map.merge(job_args)
    |> MediaDownloadWorker.new(job_opts)
    |> Tasks.create_job_with_task(media_item)
  end

  @doc """
  For a given media item, download the media alongside any options.
  Does not download media if its source is set to not download media
  (unless forced).

  Returns :ok | {:ok, %MediaItem{}} | {:error, any, ...any}
  """
  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"id" => media_item_id} = args}) do
    should_force = Map.get(args, "force", false)
    is_redownload = Map.get(args, "redownload?", false)

    media_item =
      media_item_id
      |> Media.get_media_item!()
      |> Repo.preload(:source)

    # If the source or media item is set to not download media, perform a no-op unless forced
    if (media_item.source.download_media && !media_item.prevent_download) || should_force do
      download_media_and_schedule_jobs(media_item, is_redownload)
    else
      :ok
    end
  rescue
    Ecto.NoResultsError -> Logger.info("#{__MODULE__} discarded: media item #{media_item_id} not found")
    Ecto.StaleEntryError -> Logger.info("#{__MODULE__} discarded: media item #{media_item_id} stale")
  end

  defp download_media_and_schedule_jobs(media_item, is_redownload) do
    case MediaDownloader.download_for_media_item(media_item) do
      {:ok, updated_media_item} ->
        Media.update_media_item(updated_media_item, %{
          media_size_bytes: compute_media_filesize(updated_media_item),
          media_redownloaded_at: get_redownloaded_at(is_redownload)
        })

        {:ok, updated_media_item}

      {:recovered, _} ->
        {:error, :retry}

      {:error, message} ->
        action_on_error(message)
    end
  end

  defp compute_media_filesize(media_item) do
    case File.stat(media_item.media_filepath) do
      {:ok, %{size: size}} ->
        size

      _ ->
        nil
    end
  end

  defp get_redownloaded_at(is_redownload) do
    if is_redownload do
      DateTime.utc_now()
    else
      nil
    end
  end

  defp action_on_error(message) do
    # This will attempt re-download at the next indexing, but it won't be retried
    # immediately as part of job failure logic
    non_retryable_errors = ["Video unavailable"]

    if String.contains?(to_string(message), non_retryable_errors) do
      Logger.error("yt-dlp download will not be retried: #{inspect(message)}")

      {:ok, :non_retry}
    else
      {:error, :download_failed}
    end
  end
end
