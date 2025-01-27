defmodule Pinchflat.Boot.PostBootStartupTasks do
  @moduledoc """
  This module is responsible for running startup tasks on app boot
  AFTER all other boot steps have taken place and the app is ready to serve requests.

  It's a GenServer because that plays REALLY nicely with the existing
  Phoenix supervision tree.
  """

  alias Pinchflat.YtDlp.UpdateWorker, as: YtDlpUpdateWorker

  # restart: :temporary means that this process will never be restarted (ie: will run once and then die)
  use GenServer, restart: :temporary
  import Ecto.Query, warn: false

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, %{env: Application.get_env(:pinchflat, :env)}, opts)
  end

  @doc """
  Runs post-boot application startup tasks.

  Any code defined here will run every time the application starts. You must
  make sure that the code is idempotent and safe to run multiple times.

  This is a good place to set up default settings, create initial records, stuff like that.
  Should be fast - anything with the potential to be slow should be kicked off as a job instead.
  """
  @impl true
  def init(%{env: :test} = state) do
    # Do nothing _as part of the app bootup process_.
    # Since bootup calls `start_link` and that's where the `env` state is injected,
    # you can still call `.init()` manually to run these tasks for testing purposes
    {:ok, state}
  end

  def init(state) do
    update_yt_dlp()

    {:ok, state}
  end

  defp update_yt_dlp do
    YtDlpUpdateWorker.kickoff()
  end
end
