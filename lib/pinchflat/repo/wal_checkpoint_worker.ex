defmodule Pinchflat.Repo.WalCheckpointWorker do
  @moduledoc false

  use Oban.Worker,
    queue: :local_data,
    unique: [period: 60 * 10, states: [:available, :scheduled, :retryable, :executing]],
    tags: ["local_data"]

  require Logger

  alias Pinchflat.Repo

  @doc """
  Actively checkpoints and truncates the WAL file.

  In WAL mode SQLite only checkpoints (merges the WAL back into the main db file and
  shrinks it) opportunistically, as a side effect of a write crossing the page threshold.
  If a checkpoint doesn't fully keep up for a while, the WAL keeps growing: every later
  read/write then has to work through that larger-than-necessary file, which costs more
  the slower/more virtualized the underlying storage is. Running an explicit TRUNCATE
  checkpoint on a schedule keeps the WAL small on a predictable cadence instead of
  letting it balloon indefinitely.

  This worker is scheduled to run via the Oban Cron plugin.

  Returns :ok
  """
  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    case Ecto.Adapters.SQL.query(Repo, "PRAGMA wal_checkpoint(TRUNCATE)") do
      {:ok, %{rows: [[busy, log_pages, _checkpointed_pages]]}} ->
        if busy == 1 do
          Logger.info("WAL checkpoint ran but couldn't fully truncate (busy): #{log_pages} pages remain")
        end

        :ok

      {:error, error} ->
        Logger.warning("WAL checkpoint failed: #{inspect(error)}")

        :ok
    end
  end
end
