defmodule Pinchflat.Tasks.ChannelTasks do
  @moduledoc """
  This module contains methods for managing tasks (workers) related to channels.
  """

  alias Pinchflat.MediaSource.Channel
  alias Pinchflat.Workers.MediaIndexingWorker

  @doc """
  Starts tasks for indexing a channel's media.

  TODO: modify so that updates cancel/reschedule existing tasks as-needed
  TODO: modify so that deletion cancels existing tasks (or maybe can do from Postgres?)
  TODO: modify so that starting a worker adds a Task record (not implemented yet)
  """
  def kickoff_indexing_task(%Channel{} = channel) do
    if channel.index_frequency_minutes <= 0 do
      {:ok, :should_not_index}
    else
      channel
      |> Map.take([:id])
      # Schedule this one immediately, but future ones will be on an interval
      |> MediaIndexingWorker.new()
      |> Oban.insert()
    end
  end
end
