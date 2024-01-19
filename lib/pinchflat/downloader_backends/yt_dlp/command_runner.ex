defmodule Pinchflat.DownloaderBackends.YtDlp.CommandRunner do
  @moduledoc """
  Runs yt-dlp commands using the `System.cmd/3` function
  """

  alias Pinchflat.Utils.StringUtils

  @doc """
  Runs a yt-dlp command and returns the output and status

  TODO: look into using a behavior for this (if I ever add other backends)
  """
  def run(url, command_options) do
    command = Application.get_env(:pinchflat, :backend_executables)[:yt_dlp]
    formatted_command_options = parse_options(command_options) ++ [url]

    case System.cmd(command, formatted_command_options, stderr_to_stdout: true) do
      {output, 0} -> {:ok, output}
      {output, status} -> {:error, output, status}
    end
  end

  @doc """
  Runs a yt-dlp command and returns the output as a JSON object
  """
  def run_json(url, command_options) do
    case run(url, command_options ++ [:dump_json]) do
      {:ok, output} -> {:ok, Phoenix.json_library().decode!(output)}
      res -> res
    end
  end

  # We want to satisfy the following behaviours:
  #
  # 1. If the key is an atom, convert it to a string and convert it to kebab case (for convenience)
  # 2. If the key is a string, assume we want it as-is and don't convert it
  # 3. If the key is accompanied by a value, append the value to the list
  # 4. If the key is not accompanied by a value, assume it's a flag and PREpend it to the list
  defp parse_options(command_options) do
    Enum.reduce(command_options, [], &parse_option/2)
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
end
