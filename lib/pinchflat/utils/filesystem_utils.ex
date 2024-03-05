defmodule Pinchflat.Utils.FilesystemUtils do
  @moduledoc """
  Utility methods for working with the filesystem
  """

  alias Pinchflat.Utils.StringUtils

  @doc """
  Generates a temporary file and returns its path. The file is empty and has the given type.
  Generates all the directories in the path if they don't exist.

  Returns binary()
  """
  def generate_metadata_tmpfile(type) do
    tmpfile_directory = Application.get_env(:pinchflat, :tmpfile_directory)
    filepath = Path.join([tmpfile_directory, "#{StringUtils.random_string(64)}.#{type}"])

    :ok = File.mkdir_p!(Path.dirname(filepath))
    :ok = File.write(filepath, "")

    filepath
  end
end
