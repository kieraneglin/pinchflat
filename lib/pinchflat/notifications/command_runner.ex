defmodule Pinchflat.Notifications.CommandRunner do
  @moduledoc """
  Runs apprise commands using the `System.cmd/3` function
  """

  require Logger

  alias Pinchflat.Utils.FunctionUtils

  @doc """
  # TODO
  """
  def run() do
  end

  # TODO: test
  # TODO: add behaviour
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
