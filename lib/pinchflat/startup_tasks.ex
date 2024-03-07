defmodule Pinchflat.StartupTasks do
  @moduledoc """
  This module is responsible for running startup tasks on app boot.

  It's a GenServer because that plays REALLY nicely with the existing
  Phoenix supervision tree.
  """

  # restart: :temporary means that this process will never be restarted (ie: will run once and then die)
  use GenServer, restart: :temporary

  alias Pinchflat.Settings

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, %{}, opts)
  end

  @doc """
  Runs application startup tasks.

  Any code defined here will run every time the application starts. You must
  make sure that the code is idempotent and safe to run multiple times.

  This is a good place to set up default settings, create initial records, stuff like that
  """
  @impl true
  def init(state) do
    apply_default_settings()

    {:ok, state}
  end

  defp apply_default_settings do
    Settings.fetch!(:onboarding, true)
  end
end
