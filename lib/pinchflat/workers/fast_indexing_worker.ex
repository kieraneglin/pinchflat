defmodule Pinchflat.Workers.FastIndexingWorker do
  @moduledoc false

  use Oban.Worker,
    queue: :fast_indexing,
    unique: [period: :infinity, states: [:available, :scheduled, :retryable]],
    tags: ["media_source", "fast_indexing"]

  alias __MODULE__
  alias Pinchflat.Tasks
  alias Pinchflat.Sources
  alias Pinchflat.Sources.Source
  alias Pinchflat.Tasks.SourceTasks

  @impl Oban.Worker
  @doc """
  TODO
  """
  def perform(%Oban.Job{args: %{"id" => source_id}}) do
    source = Sources.get_source!(source_id)

    if source.fast_index do
      SourceTasks.kickoff_indexing_tasks_from_youtube_rss_feed(source)

      reschedule_indexing(source)
    else
      :ok
    end
  end

  defp reschedule_indexing(source) do
    next_run_in = Source.fast_index_frequency() * 60

    %{id: source.id}
    |> FastIndexingWorker.new(schedule_in: next_run_in)
    |> Tasks.create_job_with_task(source)
    |> case do
      {:ok, task} -> {:ok, task}
      {:error, :duplicate_job} -> {:ok, :job_exists}
    end
  end
end
