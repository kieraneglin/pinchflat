defmodule Pinchflat.Boot.PreJobStartupTasks do
  @moduledoc """
  This module is responsible for running startup tasks on app boot
  BEFORE the job runner has initiallized.

  It's a GenServer because that plays REALLY nicely with the existing
  Phoenix supervision tree.
  """

  # restart: :temporary means that this process will never be restarted (ie: will run once and then die)
  use GenServer, restart: :temporary
  import Ecto.Query, warn: false
  require Logger

  alias Pinchflat.Repo
  alias Pinchflat.Settings
  alias Pinchflat.Utils.FilesystemUtils

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, %{}, opts)
  end

  @doc """
  Runs application startup tasks.

  Any code defined here will run every time the application starts. You must
  make sure that the code is idempotent and safe to run multiple times.

  This is a good place to set up default settings, create initial records, stuff like that.
  Should be fast - anything with the potential to be slow should be kicked off as a job instead.
  """
  @impl true
  def init(state) do
    reset_executing_jobs()
    create_blank_yt_dlp_files()
    apply_default_settings()

    {:ok, state}
  end

  # If a node cannot gracefully shut down, the currently executing jobs get stuck
  # in the "executing" state. This is a problem because the job runner will not
  # pick them up again
  defp reset_executing_jobs do
    {count, _} =
      Oban.Job
      |> where(state: "executing")
      |> Repo.update_all(set: [state: "retryable"])

    Logger.info("Reset #{count} executing jobs")
  end

  defp create_blank_yt_dlp_files do
    files = ["cookies.txt", "yt-dlp-config.txt"]
    base_dir = Application.get_env(:pinchflat, :extras_directory)

    Enum.each(files, fn file ->
      filepath = Path.join(base_dir, file)

      if !File.exists?(filepath) do
        Logger.info("Creating blank file: #{filepath}")

        FilesystemUtils.write_p!(filepath, "")
      end
    end)
  end

  defp apply_default_settings do
    {:ok, yt_dlp_version} = yt_dlp_runner().version()
    {:ok, apprise_version} = apprise_runner().version()

    Settings.set(yt_dlp_version: yt_dlp_version)
    Settings.set(apprise_version: apprise_version)
  end

  defp yt_dlp_runner do
    Application.get_env(:pinchflat, :yt_dlp_runner)
  end

  defp apprise_runner do
    Application.get_env(:pinchflat, :apprise_runner)
  end
end
