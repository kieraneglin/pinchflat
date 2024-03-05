defmodule Pinchflat.Utils.FilesystemUtils.FileFollowerServer do
  @moduledoc """
  A GenServer that watches a file for new lines and processes them as they come in.
  This is useful for tailing log files and other similar tasks. If there's no activity
  for a certain amount of time, the server will stop itself.
  """
  use GenServer

  require Logger

  @poll_interval_ms Application.compile_env(:pinchflat, :file_watcher_poll_interval)
  @activity_timeout_ms 60_000

  # Client API
  @doc """
  Starts the file follower server

  Returns {:ok, pid} or {:error, reason}
  """
  def start_link() do
    GenServer.start_link(__MODULE__, [])
  end

  @doc """
  Starts the file watcher for a given filepath and handler function.

  Returns :ok
  """
  def watch_file(process, filepath, handler) do
    GenServer.cast(process, {:watch_file, filepath, handler})
  end

  @doc """
  Stops the file watcher and closes the file.

  Returns :ok
  """
  def stop(process) do
    GenServer.cast(process, :stop)
  end

  # Server Callbacks
  @impl true
  def init(_opts) do
    # Start with a blank state because, based on the common calling
    # pattern for this module, we'll need a reference to the server's
    # PID before we start watching any files so we can later stop the
    # server gracefully.
    {:ok, %{}}
  end

  @impl true
  def handle_cast({:watch_file, filepath, handler}, _old_state) do
    {:ok, io_device} = :file.open(filepath, [:raw, :read_ahead, :binary])

    state = %{
      io_device: io_device,
      last_activity: DateTime.utc_now(),
      handler: handler
    }

    Process.send(self(), :read_new_lines, [])

    {:noreply, state}
  end

  @impl true
  def handle_cast(:stop, state) do
    Logger.debug("Gracefully stopping file follower")
    :file.close(state.io_device)

    {:stop, :normal, state}
  end

  @impl true
  def handle_info(:read_new_lines, state) do
    last_activity = state.last_activity

    # If there's no new lines written for a certain amount of time, stop the server
    if DateTime.diff(DateTime.utc_now(), last_activity, :millisecond) > @activity_timeout_ms do
      Logger.debug("No activity for #{@activity_timeout_ms}ms. Requesting stop.")
      stop(self())

      {:noreply, state}
    else
      attempt_process_new_lines(state)
    end
  end

  defp attempt_process_new_lines(state) do
    io_device = state.io_device

    # This reads one line at a time. If a line is found, it
    # will be passed to the handler, we'll note the time of
    # the last activity, and then we'll immediately call this
    # again to read the next line.
    #
    # If there are no lines, it waits for the poll interval
    # before trying again.
    case :file.read_line(io_device) do
      {:ok, line} ->
        state.handler.(line)

        Process.send(self(), :read_new_lines, [])

        {:noreply, %{state | last_activity: DateTime.utc_now()}}

      :eof ->
        Logger.debug("EOF reached, waiting before trying to read new lines")
        Process.send_after(self(), :read_new_lines, @poll_interval_ms)

        {:noreply, state}

      {:error, reason} ->
        Logger.error("Error reading file: #{reason}")
        stop(self())

        {:noreply, state}
    end
  end
end
