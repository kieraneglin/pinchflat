defmodule Pinchflat.Utils.FilesystemUtils do
  @moduledoc """
  Utility methods for working with the filesystem
  """
  alias Pinchflat.Media
  alias Pinchflat.Utils.StringUtils

  @doc """
  Checks if a file exists and has non-whitespace contents.

  Returns boolean()
  """
  def exists_and_nonempty?(filepath) do
    case File.read(filepath) do
      {:ok, contents} ->
        String.trim(contents) != ""

      _ ->
        false
    end
  end

  @doc """
  Checks if two filepaths reference the same file.

  Useful if you have a relative and absolute filepath and want to be sure they're the same file.
  Also works with symlinks.

  Returns boolean()
  """
  def filepaths_reference_same_file?(filepath_1, filepath_2) do
    {:ok, stat_1} = File.stat(filepath_1)
    {:ok, stat_2} = File.stat(filepath_2)

    identifier_1 = "#{stat_1.major_device}:#{stat_1.minor_device}:#{stat_1.inode}"
    identifier_2 = "#{stat_2.major_device}:#{stat_2.minor_device}:#{stat_2.inode}"

    identifier_1 == identifier_2
  end

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
  Takes the same args as File.write/3.

  Returns :ok | {:error, any()}
  """
  def write_p(file, content, modes \\ []) do
    dirname = Path.dirname(file)

    case File.mkdir_p(dirname) do
      :ok -> File.write(file, content, modes)
      err -> err
    end
  end

  @doc """
  Writes content to a file, creating directories as needed.
  Takes the same args as File.write!/3.

  Returns :ok | raises on error
  """
  def write_p!(filepath, content, modes \\ []) do
    :ok = write_p(filepath, content, modes)
  end

  @doc """
  Copies a file from source to destination, creating directories as needed.

  Returns :ok | raises on error
  """
  def cp_p!(source, destination) do
    destination
    |> Path.dirname()
    |> File.mkdir_p!()

    File.cp!(source, destination)
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

  @doc """
  Deletes a file and removes any empty directories in the path.
  Does NOT remove any directories that are not empty.

  Returns :ok | {:error, any()}
  """
  def delete_file_and_remove_empty_directories(filepath) do
    case File.rm(filepath) do
      :ok ->
        filepath
        |> Path.dirname()
        |> recursively_delete_empty_directories()

      err ->
        err
    end
  end

  defp recursively_delete_empty_directories(directory) do
    case File.rmdir(directory) do
      :ok ->
        directory
        |> Path.dirname()
        |> recursively_delete_empty_directories()

      err ->
        err
    end

    :ok
  end
end
