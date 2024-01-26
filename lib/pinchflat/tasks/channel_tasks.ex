defmodule Pinchflat.Tasks.ChannelTasks do
  @moduledoc """
  This module contains methods for managing tasks (workers) related to channels.
  """

  alias Pinchflat.Tasks
  alias Pinchflat.MediaSource.Channel
  alias Pinchflat.Workers.MediaIndexingWorker

  @doc """
  Starts tasks for indexing a channel's media. Returns {:ok, :should_not_index} | {:ok, %Task{}}.
  """
  def kickoff_indexing_task(%Channel{} = channel) do
    Tasks.delete_pending_tasks_for(channel)

    if channel.index_frequency_minutes <= 0 do
      {:ok, :should_not_index}
    else
      channel
      |> Map.take([:id])
      # Schedule this one immediately, but future ones will be on an interval
      |> MediaIndexingWorker.new()
      |> Tasks.create_job_with_task(channel)
    end
  end
end
