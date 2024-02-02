defmodule Pinchflat.Tasks.ChannelTasks do
  @moduledoc """
  This module contains methods for managing tasks (workers) related to channels.
  """

  alias Pinchflat.Tasks
  alias Pinchflat.MediaSource.Source
  alias Pinchflat.Workers.MediaIndexingWorker

  @doc """
  Starts tasks for indexing a source's media.

  Returns {:ok, :should_not_index} | {:ok, %Task{}}.
  """
  def kickoff_indexing_task(%Source{} = source) do
    Tasks.delete_pending_tasks_for(source)

    if source.index_frequency_minutes <= 0 do
      {:ok, :should_not_index}
    else
      source
      |> Map.take([:id])
      # Schedule this one immediately, but future ones will be on an interval
      |> MediaIndexingWorker.new()
      |> Tasks.create_job_with_task(source)
      |> case do
        # This should never return {:error, :duplicate_job} since we just deleted
        # any pending tasks. I'm being assertive about it so it's obvious if I'm wrong
        {:ok, task} -> {:ok, task}
      end
    end
  end
end
