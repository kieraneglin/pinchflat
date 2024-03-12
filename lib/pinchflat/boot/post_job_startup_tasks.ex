defmodule Pinchflat.Boot.PostJobStartupTasks do
  @moduledoc """
  This module is responsible for running startup tasks on app boot
  AFTER the job runner has initiallized.

  It's a GenServer because that plays REALLY nicely with the existing
  Phoenix supervision tree.
  """

  # restart: :temporary means that this process will never be restarted (ie: will run once and then die)
  use GenServer, restart: :temporary
  import Ecto.Query, warn: false

  alias Pinchflat.Repo
  alias Pinchflat.Boot.DataBackfillWorker

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
    enqueue_backfill_worker()

    {:ok, state}
  end

  defp enqueue_backfill_worker do
    DataBackfillWorker.cancel_pending_backfill_jobs()

    %{}
    |> DataBackfillWorker.new()
    |> Repo.insert_unique_job()
  end
end
