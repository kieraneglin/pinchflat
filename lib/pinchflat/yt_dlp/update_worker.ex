defmodule Pinchflat.YtDlp.UpdateWorker do
  @moduledoc false

  use Oban.Worker,
    queue: :local_data,
    tags: ["local_data"]

  require Logger

  alias Pinchflat.Settings

  @doc """
  Updates yt-dlp and saves the version to the settings.

  This worker is scheduled to run via the Oban Cron plugin.

  Returns :ok
  """
  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    Logger.info("Updating yt-dlp")

    yt_dlp_runner().update()

    {:ok, yt_dlp_version} = yt_dlp_runner().version()
    Settings.set(yt_dlp_version: yt_dlp_version)

    :ok
  end

  defp yt_dlp_runner do
    Application.get_env(:pinchflat, :yt_dlp_runner)
  end
end
