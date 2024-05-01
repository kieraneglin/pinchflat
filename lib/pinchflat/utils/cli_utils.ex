defmodule Pinchflat.Utils.CliUtils do
  @moduledoc """
  Utility methods for working with CLI executables
  """

  require Logger

  alias Pinchflat.Utils.StringUtils

  @doc """
  Wraps a command in a shell script that will terminate
  the command if stdin is closed. Useful for stopping
  commands if the job runner is cancelled.

  Delegates to `System.cmd/3` and any options/output
  are passed through. Custom options can be passed in.

  Custom options:
    - logging_arg_override: if set, the passed value will be logged in place of
      the actual arguments passed to the command

  Returns {binary(), integer()}
  """
  def wrap_cmd(command, args, passthrough_opts \\ [], opts \\ []) do
    wrapper_command = Path.join(:code.priv_dir(:pinchflat), "cmd_wrapper.sh")
    actual_command = [command] ++ args
    logging_arg_override = Keyword.get(opts, :logging_arg_override, Enum.join(args, " "))

    Logger.info("[command_wrapper]: #{command} called with: #{logging_arg_override}")

    System.cmd(wrapper_command, actual_command, passthrough_opts)
  end

  @doc """
  Parses a list of command options into a list of strings suitable for passing to
  `System.cmd/3`.

  We want to satisfy the following behaviours:
    1. If the key is an atom, convert it to a string and convert it to kebab case (for convenience)
    2. If the key is a string, assume we want it as-is and don't convert it
    3. If the key is accompanied by a value, append the value to the list
    4. If the key is not accompanied by a value, assume it's a flag and PREpend it to the list

  Returns [binary()]
  """
  def parse_options(command_opts) do
    command_opts
    |> List.wrap()
    |> Enum.reduce([], &parse_option/2)
  end

  defp parse_option({k, v}, acc) when is_atom(k) do
    stringified_key = StringUtils.to_kebab_case(Atom.to_string(k))

    parse_option({"--#{stringified_key}", v}, acc)
  end

  defp parse_option({k, v}, acc) when is_binary(k) do
    acc ++ [k, to_string(v)]
  end

  defp parse_option(arg, acc) when is_atom(arg) do
    stringified_arg =
      arg
      |> Atom.to_string()
      |> StringUtils.to_kebab_case()

    parse_option("--#{stringified_arg}", acc)
  end

  defp parse_option(arg, acc) when is_binary(arg) do
    acc ++ [arg]
  end
end
