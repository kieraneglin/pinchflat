defmodule Pinchflat.Notifications.CommandRunner do
  @moduledoc """
  Runs apprise commands using the `System.cmd/3` function
  """

  require Logger

  alias Pinchflat.Utils.CliUtils
  alias Pinchflat.Utils.FunctionUtils
  alias Pinchflat.Notifications.AppriseCommandRunner

  @behaviour AppriseCommandRunner

  @doc """
  Runs an apprise command and returns the string output.
  Can take a single server string or a list of servers as well as additional
  arguments to pass to the command.

  Returns {:ok, binary()} | {:error, :no_servers} | {:error, binary()}
  """
  @impl AppriseCommandRunner
  def run(nil, _), do: {:error, :no_servers}
  def run("", _), do: {:error, :no_servers}
  def run([], _), do: {:error, :no_servers}

  def run(endpoints, command_opts) do
    endpoints = List.wrap(endpoints)
    default_opts = [:verbose]
    parsed_opts = CliUtils.parse_options(default_opts ++ command_opts)

    Logger.info("[apprise] called with: #{Enum.join(parsed_opts ++ endpoints, " ")}")
    {output, return_code} = System.cmd(backend_executable(), parsed_opts ++ endpoints)
    Logger.info("[apprise] response: #{output}")

    case return_code do
      0 -> {:ok, String.trim(output)}
      _ -> {:error, String.trim(output)}
    end
  end

  @doc """
  Returns the version of apprise as a string.

  Returns {:ok, binary()} | {:error, binary()}
  """
  @impl AppriseCommandRunner
  def version do
    case System.cmd(backend_executable(), ["--version"]) do
      {output, 0} ->
        output
        |> String.split(~r{\r?\n})
        |> List.first()
        |> String.replace("Apprise", "")
        |> String.trim()
        |> FunctionUtils.wrap_ok()

      {output, _} ->
        {:error, output}
    end
  end

  defp backend_executable do
    Application.get_env(:pinchflat, :apprise_executable)
  end
end
