defmodule Pinchflat.Downloader.Backends.YtDlp.CommandRunner do
  @moduledoc """
  Runs yt-dlp commands using the `System.cmd/3` function
  """

  alias Pinchflat.Utils.StringUtils
  alias Pinchflat.Downloader.Backends.BackendCommandRunner

  @behaviour BackendCommandRunner

  @doc """
  Runs a yt-dlp command and returns the string output

  # IDEA: deduplicate command opts, keeping the last one on conflict
          although possibly not needed (and a LOT easier) if yt-dlp
          just ignores duplicate options (ie: look into that)
  """
  @impl BackendCommandRunner
  def run(url, command_opts) do
    command = backend_executable()
    formatted_command_opts = parse_options(command_opts) ++ [url]

    case System.cmd(command, formatted_command_opts, stderr_to_stdout: true) do
      {output, 0} -> {:ok, output}
      {output, status} -> {:error, output, status}
    end
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
    [arg | acc]
  end

  defp backend_executable do
    Application.get_env(:pinchflat, :yt_dlp_executable)
  end
end
