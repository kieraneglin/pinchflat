defmodule Pinchflat.Utils.CliUtils do
  @moduledoc """
  Utility methods for working with CLI executables
  """

  alias Pinchflat.Utils.StringUtils

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
