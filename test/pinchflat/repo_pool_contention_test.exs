defmodule Pinchflat.RepoPoolContentionTest do
  @moduledoc """
  Reproduces the actual mechanism behind the "Database busy" crashes (#832/#873/#903/
  #762) and the 20-34s Oban Pruner stalls seen in production: SQLite allows exactly one
  writer no matter how many connections ask for one. `Pinchflat.Repo` used pool_size: 5,
  so up to 5 independent OS-level SQLite connections could all try to write at once and
  fight over that single lock. On fast local disk each hold is short enough that this
  rarely bites; on slower/virtualized storage (this host's /config is 9p-mounted) a hold
  lasting past the 2s default busy_timeout turns into an outright error for every other
  connection queued behind it.

  Raising busy_timeout (the previous approach) just makes losers wait longer instead of
  erroring - it doesn't stop them from queueing up in the first place. Serializing to a
  single connection (pool_size: 1) removes the contention at its source: Ecto queues the
  requests cheaply in BEAM instead of SQLite retrying a disk-level lock.

  Tests here use raw Exqlite connections (not Pinchflat.Repo) because the SQLite
  adapter's Sandbox pool doesn't model real multi-connection file locking.
  """

  use ExUnit.Case, async: false

  alias Exqlite.Sqlite3

  # busy_timeout is set to 500ms (below Exqlite's real 2000ms default) purely so the
  # test's queueing math is deterministic and the suite stays fast; the mechanism it
  # proves - queued connections eventually exceed whatever timeout they're given - is
  # exactly what happened in production with the real 2000ms default once enough
  # connections queued up behind a slow write.
  @slow_write_ms 300

  setup do
    path = Path.join(System.tmp_dir!(), "pool_contention_test_#{System.unique_integer([:positive])}.db")

    on_exit(fn ->
      File.rm(path)
      File.rm(path <> "-wal")
      File.rm(path <> "-shm")
    end)

    {:ok, setup_conn} = Sqlite3.open(path)
    :ok = Sqlite3.execute(setup_conn, "PRAGMA journal_mode=WAL")
    :ok = Sqlite3.execute(setup_conn, "CREATE TABLE t (v INTEGER)")
    :ok = Sqlite3.close(setup_conn)

    {:ok, path: path}
  end

  # Mimics one DBConnection connection out of the pool doing a write slow enough to
  # matter on contended/virtualized storage (production saw single writes take seconds).
  defp slow_write(path, value) do
    {:ok, conn} = Sqlite3.open(path)
    :ok = Sqlite3.execute(conn, "PRAGMA busy_timeout = 500")

    result =
      with :ok <- Sqlite3.execute(conn, "BEGIN IMMEDIATE") do
        Process.sleep(@slow_write_ms)
        Sqlite3.execute(conn, "INSERT INTO t (v) VALUES (#{value})")
      end

    case result do
      :ok -> Sqlite3.execute(conn, "COMMIT")
      _ -> Sqlite3.execute(conn, "ROLLBACK")
    end

    Sqlite3.close(conn)
    result
  end

  test "pool_size 5 style: multiple independent connections racing the same write produce busy errors", %{
    path: path
  } do
    results =
      1..5
      |> Enum.map(fn i -> Task.async(fn -> slow_write(path, i) end) end)
      |> Enum.map(&Task.await(&1, 5_000))

    assert Enum.any?(results, &match?({:error, _}, &1)),
           "expected at least one connection to lose the race and get a busy/locked error, got: #{inspect(results)}"
  end

  test "pool_size 1 style: the same writes serialized through one connection never error", %{path: path} do
    {:ok, conn} = Sqlite3.open(path)
    :ok = Sqlite3.execute(conn, "PRAGMA busy_timeout = 500")

    results =
      Enum.map(1..5, fn i ->
        :ok = Sqlite3.execute(conn, "BEGIN IMMEDIATE")
        Process.sleep(@slow_write_ms)
        result = Sqlite3.execute(conn, "INSERT INTO t (v) VALUES (#{i})")
        if result == :ok, do: Sqlite3.execute(conn, "COMMIT"), else: Sqlite3.execute(conn, "ROLLBACK")
        result
      end)

    Sqlite3.close(conn)

    assert Enum.all?(results, &(&1 == :ok)),
           "expected every serialized write to succeed with no contention, got: #{inspect(results)}"
  end
end
