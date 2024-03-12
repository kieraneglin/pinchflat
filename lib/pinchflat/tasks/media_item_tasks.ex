defmodule Pinchflat.Tasks.MediaItemTasks do
  @moduledoc """
  Contains methods used by OR used to create/manage tasks for media items.

  Tasks/workers are meant to be thin wrappers so most of the actual work they
  do is also defined here. Essentially, a one-stop-shop for media-related tasks/workers.
  """
  alias Pinchflat.Media
  alias Pinchflat.Tasks
  alias Pinchflat.Sources.Source
  alias Pinchflat.Downloading.MediaDownloadWorker

  alias Pinchflat.YtDlp.Backend.Media, as: YtDlpMedia

  @doc """
  Fetches the file size of a media item and saves it to the database.

  Returns {:ok, media_item} | {:error, any()}
  """
  def compute_and_save_media_filesize(media_item) do
    case File.stat(media_item.media_filepath) do
      {:ok, %{size: size}} ->
        Media.update_media_item(media_item, %{media_size_bytes: size})

      err ->
        err
    end
  end

  @doc """
  Indexes a single media item for a source and enqueues a download job if the
  media should be downloaded. This method creates the media item record so it's
  the one-stop-shop for adding a media item (and possibly downloading it) just
  by a URL and source.

  Returns {:ok, media_item} | {:error, any()}
  """
  def index_and_enqueue_download_for_media_item(%Source{} = source, url) do
    maybe_media_item = create_media_item_from_url(source, url)

    case maybe_media_item do
      {:ok, media_item} ->
        if source.download_media && Media.pending_download?(media_item) do
          %{id: media_item.id}
          |> MediaDownloadWorker.new()
          |> Tasks.create_job_with_task(media_item)
        end

        {:ok, media_item}

      err ->
        err
    end
  end

  defp create_media_item_from_url(source, url) do
    {:ok, media_attrs} = YtDlpMedia.get_media_attributes(url)

    Media.create_media_item_from_backend_attrs(source, media_attrs)
  end
end
