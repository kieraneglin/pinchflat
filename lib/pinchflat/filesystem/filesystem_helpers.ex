defmodule Pinchflat.Filesystem.FilesystemHelpers do
  @moduledoc """
  Utility methods for working with the filesystem
  """
  alias Pinchflat.Media
  alias Pinchflat.Utils.StringUtils

  @doc """
  Generates a temporary file and returns its path. The file is empty and has the given type.
  Generates all the directories in the path if they don't exist.

  Returns binary()
  """
  def generate_metadata_tmpfile(type) do
    tmpfile_directory = Application.get_env(:pinchflat, :tmpfile_directory)
    filepath = Path.join([tmpfile_directory, "#{StringUtils.random_string(64)}.#{type}"])

    :ok = write_p!(filepath, "")

    filepath
  end

  @doc """
  Writes content to a file, creating directories as needed.
  Takes the same args as File.write!/3.

  Returns :ok | raises on error
  """
  def write_p!(filepath, content, modes \\ []) do
    filepath
    |> Path.dirname()
    |> File.mkdir_p!()

    File.write!(filepath, content, modes)
  end

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
