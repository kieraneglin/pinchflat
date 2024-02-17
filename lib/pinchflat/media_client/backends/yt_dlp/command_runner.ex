defmodule Pinchflat.MediaClient.Backends.YtDlp.CommandRunner do
  @moduledoc """
  Runs yt-dlp commands using the `System.cmd/3` function
  """

  require Logger

  alias Pinchflat.Utils.StringUtils
  alias Pinchflat.MediaClient.Backends.BackendCommandRunner

  @behaviour BackendCommandRunner

  @doc """
  Runs a yt-dlp command and returns the string output. Saves the output to
  a file and then returns its contents because yt-dlp will return warnings
  to stdout even if the command is successful, but these will break JSON parsing.

  Returns {:ok, binary()} | {:error, output, status}.

  IDEA: Indexing takes a long time, but the output is actually streamed to stdout.
  Maybe we could listen to that stream instead so we can index videos as they're discovered.
  See: https://stackoverflow.com/a/49061086/5665799
  """
  @impl BackendCommandRunner
  def run(url, command_opts, output_template) do
    command = backend_executable()
    # These must stay in exactly this order, hence why I'm giving it its own variable.
    # Also, can't use RAM file since yt-dlp needs a concrete filepath.
    json_output_path = generate_json_output_path()
    print_to_file_opts = [{:print_to_file, output_template}, json_output_path]
    formatted_command_opts = [url] ++ parse_options(command_opts ++ print_to_file_opts)

    Logger.info("[yt-dlp] called with: #{Enum.join(formatted_command_opts, " ")}")

    case System.cmd(command, formatted_command_opts, stderr_to_stdout: true) do
      {_, 0} ->
        # IDEA: consider deleting the file after reading it
        # (even on error? especially on error?)
        File.read(json_output_path)

      {output, status} ->
        {:error, output, status}
    end
  end

  defp generate_json_output_path do
    metadata_directory = Application.get_env(:pinchflat, :metadata_directory)
    filepath = Path.join([metadata_directory, "#{StringUtils.random_string(64)}.json"])

    # Ensure the file can be created and written to BEFORE we run the `yt-dlp` command
    :ok = File.mkdir_p!(Path.dirname(filepath))
    :ok = File.write(filepath, "")

    filepath
  end

  # We want to satisfy the following behaviours:
  #
  # 1. If the key is an atom, convert it to a string and convert it to kebab case (for convenience)
  # 2. If the key is a string, assume we want it as-is and don't convert it
  # 3. If the key is accompanied by a value, append the value to the list
  # 4. If the key is not accompanied by a value, assume it's a flag and PREpend it to the list
  defp parse_options(command_opts) do
    Enum.reduce(command_opts, [], &parse_option/2)
  end

  defp parse_option({k, v}, acc) when is_atom(k) do
    stringified_key = StringUtils.to_kebab_case(Atom.to_string(k))

    parse_option({"--#{stringified_key}", v}, acc)
  end

  defp parse_option({k, v}, acc) when is_binary(k) do
    acc ++ [k, to_string(v)]
  end

  defp parse_option(arg, acc) when is_atom(arg) do
    stringified_arg = StringUtils.to_kebab_case(Atom.to_string(arg))

    parse_option("--#{stringified_arg}", acc)
  end

  defp parse_option(arg, acc) when is_binary(arg) do
    acc ++ [arg]
  end

  defp backend_executable do
    Application.get_env(:pinchflat, :yt_dlp_executable)
  end
end
