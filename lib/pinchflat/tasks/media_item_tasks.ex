defmodule Pinchflat.Tasks.MediaItemTasks do
  @moduledoc """
  This module contains methods used by or used to control tasks (aka workers)
  related to media items.
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
