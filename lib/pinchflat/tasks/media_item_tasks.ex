defmodule Pinchflat.Tasks.MediaItemTasks do
  @moduledoc """
  Contains methods used by OR used to create/manage tasks for media items.

  Tasks/workers are meant to be thin wrappers so most of the actual work they
  do is also defined here. Essentially, a one-stop-shop for media-related tasks/workers.
  """
  alias Pinchflat.Media

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
end
