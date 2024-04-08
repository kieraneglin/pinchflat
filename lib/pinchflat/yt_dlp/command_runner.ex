defmodule Pinchflat.YtDlp.CommandRunner do
  @moduledoc """
  Runs yt-dlp commands using the `System.cmd/3` function
  """

  require Logger

  alias Pinchflat.Utils.CliUtils
  alias Pinchflat.YtDlp.YtDlpCommandRunner
  alias Pinchflat.Filesystem.FilesystemHelpers, as: FSUtils

  @behaviour YtDlpCommandRunner

  @doc """
  Runs a yt-dlp command and returns the string output. Saves the output to
  a file and then returns its contents because yt-dlp will return warnings
  to stdout even if the command is successful, but these will break JSON parsing.

  Additional Opts:
    - :output_filepath - the path to save the output to. If not provided, a temporary
      file will be created and used. Useful for if you need a reference to the file
      for a file watcher.

  Returns {:ok, binary()} | {:error, output, status}.
  """
  @impl YtDlpCommandRunner
  def run(url, command_opts, output_template, addl_opts \\ []) do
    # This approach lets us mock the command for testing
    command = backend_executable()
    # These must stay in exactly this order, hence why I'm giving it its own variable.
    # Also, can't use RAM file since yt-dlp needs a concrete filepath.
    output_filepath = generate_output_filepath(addl_opts)
    print_to_file_opts = [{:print_to_file, output_template}, output_filepath]
    cookie_opts = build_cookie_options()
    formatted_command_opts = [url] ++ CliUtils.parse_options(command_opts ++ print_to_file_opts ++ cookie_opts)

    Logger.info("[yt-dlp] called with: #{Enum.join(formatted_command_opts, " ")}")

    case System.cmd(command, formatted_command_opts, stderr_to_stdout: true) do
      {_, 0} ->
        # IDEA: consider deleting the file after reading it. It's in the tmp dir, so it's not
        # a huge deal, but it's still a good idea to clean up after ourselves.
        # (even on error? especially on error?)
        File.read(output_filepath)

      {output, status} ->
        {:error, output, status}
    end
  end

  @doc """
  Returns the version of yt-dlp as a string

  Returns {:ok, binary()} | {:error, binary()}
  """
  @impl YtDlpCommandRunner
  def version do
    command = backend_executable()

    case System.cmd(command, ["--version"]) do
      {output, 0} ->
        {:ok, String.trim(output)}

      {output, _} ->
        {:error, output}
    end
  end

  defp generate_output_filepath(addl_opts) do
    case Keyword.get(addl_opts, :output_filepath) do
      nil -> FSUtils.generate_metadata_tmpfile(:json)
      path -> path
    end
  end

  defp build_cookie_options do
    base_dir = Application.get_env(:pinchflat, :extras_directory)
    cookie_file = Path.join(base_dir, "cookies.txt")

    case File.read(cookie_file) do
      {:ok, cookie_data} ->
        if String.trim(cookie_data) != "", do: [cookies: cookie_file], else: []

      {:error, _} ->
        []
    end
  end

  defp backend_executable do
    Application.get_env(:pinchflat, :yt_dlp_executable)
  end
end
