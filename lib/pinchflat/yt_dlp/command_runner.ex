defmodule Pinchflat.YtDlp.CommandRunner do
  @moduledoc """
  Runs yt-dlp commands using the `System.cmd/3` function
  """

  require Logger

  alias Pinchflat.Settings
  alias Pinchflat.Utils.CliUtils
  alias Pinchflat.Utils.NumberUtils
  alias Pinchflat.YtDlp.YtDlpCommandRunner
  alias Pinchflat.Utils.FilesystemUtils, as: FSUtils

  @behaviour YtDlpCommandRunner

  @doc """
  Runs a yt-dlp command and returns the string output. Saves the output to
  a file and then returns its contents because yt-dlp will return warnings
  to stdout even if the command is successful, but these will break JSON parsing.

  Additional Opts:
    - :output_filepath - the path to save the output to. If not provided, a temporary
      file will be created and used. Useful for if you need a reference to the file
      for a file watcher.
    - :use_cookies - if true, will add a cookie file to the command options. Will not
      attach a cookie file if the user hasn't set one up.
    - :skip_sleep_interval - if true, will not add the sleep interval options to the command.
      Usually only used for commands that would be UI-blocking

  Returns {:ok, binary()} | {:error, output, status}.
  """
  @impl YtDlpCommandRunner
  def run(url, action_name, command_opts, output_template, addl_opts \\ []) do
    Logger.debug("Running yt-dlp command for action: #{action_name}")

    output_filepath = generate_output_filepath(addl_opts)
    print_to_file_opts = [{:print_to_file, output_template}, output_filepath]
    user_configured_opts = cookie_file_options(addl_opts) ++ sleep_interval_opts(addl_opts)
    # These must stay in exactly this order, hence why I'm giving it its own variable.
    all_opts = command_opts ++ print_to_file_opts ++ user_configured_opts ++ global_options()
    formatted_command_opts = [url] ++ CliUtils.parse_options(all_opts)

    case CliUtils.wrap_cmd(backend_executable(), formatted_command_opts, stderr_to_stdout: true) do
      # yt-dlp exit codes:
      #   0 = Everything is successful
      #   100 = yt-dlp must restart for update to complete
      #   101 = Download cancelled by --max-downloads etc
      #     2 = Error in user-provided options
      #     1 = Any other error
      {_, status} when status in [0, 101] ->
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

    case CliUtils.wrap_cmd(command, ["--version"]) do
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

  defp global_options do
    [
      :windows_filenames,
      :quiet,
      cache_dir: Path.join(Application.get_env(:pinchflat, :tmpfile_directory), "yt-dlp-cache")
    ]
  end

  defp cookie_file_options(addl_opts) do
    case Keyword.get(addl_opts, :use_cookies) do
      true -> add_cookie_file()
      _ -> []
    end
  end

  defp sleep_interval_opts(addl_opts) do
    sleep_interval = Settings.get!(:extractor_sleep_interval)

    if sleep_interval <= 0 || Keyword.get(addl_opts, :skip_sleep_interval) do
      []
    else
      [
        sleep_requests: NumberUtils.add_jitter(sleep_interval),
        sleep_interval: NumberUtils.add_jitter(sleep_interval),
        sleep_subtitles: NumberUtils.add_jitter(sleep_interval)
      ]
    end
  end

  defp add_cookie_file do
    base_dir = Application.get_env(:pinchflat, :extras_directory)
    filename_options_map = %{cookies: "cookies.txt"}

    Enum.reduce(filename_options_map, [], fn {opt_name, filename}, acc ->
      filepath = Path.join(base_dir, filename)

      if FSUtils.exists_and_nonempty?(filepath) do
        [{opt_name, filepath} | acc]
      else
        acc
      end
    end)
  end

  defp backend_executable do
    Application.get_env(:pinchflat, :yt_dlp_executable)
  end
end
