defmodule Pinchflat.KilledWorker do
  @moduledoc false

  use Oban.Worker,
    queue: :default

  import Ecto.Query, warn: false

  require Logger

  alias __MODULE__
  alias Pinchflat.Repo

  def kickoff(job_args \\ %{}, opts \\ []) do
    job_args
    |> KilledWorker.new(opts)
    |> Repo.insert_unique_job()

    :ok
  end

  def cancel do
    Oban.Job
    |> where(worker: "Pinchflat.KilledWorker")
    |> Oban.cancel_all_jobs()
  end

  def start_stop do
    kickoff()
    Process.sleep(2000)
    cancel()
  end

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    # case System.cmd("/app/wrapper.sh", ["/app/slow.sh"]) do
    args = [
      "/usr/local/bin/yt-dlp",
      "https://www.youtube.com/@OverSimplified",
      "--simulate",
      "--print",
      "%(title)s"
    ]

    case System.cmd("/app/wrapper.sh", args) do
      {output, 0} ->
        Logger.warning("KilledWorker: #{output}")
        {:ok, output}

      {output, _} ->
        Logger.error("KilledWorker: #{output}")
        {:error, output}
    end

    Logger.warning("KilledWorker: done")
    :ok
  end
end
