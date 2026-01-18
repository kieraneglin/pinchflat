defmodule Pinchflat.YtDlp.UpdateWorker do
  @moduledoc """
  Handles automatic yt-dlp updates based on the YT_DLP_VERSION environment variable.

  Supported values for YT_DLP_VERSION:
    - "stable" (default) - updates to latest stable release daily
    - "nightly" - updates to latest nightly build daily
    - "master" - updates to latest master build daily
    - "pinned" or "none" - disables automatic updates entirely
    - A specific version like "2025.12.08" - pins to that exact version
  """

  use Oban.Worker,
    queue: :local_data,
    tags: ["local_data"]

  require Logger

  alias __MODULE__
  alias Pinchflat.Settings

  @doc """
  Starts the yt-dlp update worker. Does not attach it to a task like `kickoff_with_task/2`

  Returns {:ok, %Oban.Job{}} | {:error, %Ecto.Changeset{}}
  """
  def kickoff do
    Oban.insert(UpdateWorker.new(%{}))
  end

  @doc """
  Updates yt-dlp and saves the version to the settings.

  This worker is scheduled to run via the Oban Cron plugin as well as on app boot.
  The update behavior is controlled by the YT_DLP_VERSION environment variable.

  Returns :ok
  """
  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    version_setting = get_version_setting()

    case version_setting do
      setting when setting in ["pinned", "none"] ->
        Logger.info("yt-dlp auto-update disabled (YT_DLP_VERSION=#{setting})")

      version_target ->
        Logger.info("Updating yt-dlp to #{version_target}")
        yt_dlp_runner().update(version_target)
    end

    {:ok, yt_dlp_version} = yt_dlp_runner().version()
    Settings.set(yt_dlp_version: yt_dlp_version)

    :ok
  end

  @doc """
  Returns the configured yt-dlp version setting from environment.
  """
  def get_version_setting do
    Application.get_env(:pinchflat, :yt_dlp_version_channel, "stable")
  end

  defp yt_dlp_runner do
    Application.get_env(:pinchflat, :yt_dlp_runner)
  end
end
