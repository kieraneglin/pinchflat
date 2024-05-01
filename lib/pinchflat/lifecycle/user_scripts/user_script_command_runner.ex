defmodule Pinchflat.Lifecycle.UserScripts.UserScriptCommandRunner do
  @moduledoc """
  A behaviour for running custom user scripts on certain events.

  Used so we can implement Mox for testing without actually running the
  user's command.
  """

  @callback run(atom(), map()) :: :ok | {:error, binary()}
end
