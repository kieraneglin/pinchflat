defmodule Pinchflat.Sources.SourceDeletionWorker do
  @moduledoc false

  use Oban.Worker,
    queue: :local_data,
    tags: ["sources", "local_data"]

  require Logger

  alias __MODULE__
  alias Pinchflat.Sources

  @doc """
  Starts the source deletion worker. Does not attach it to a task like `kickoff_with_task/2`
  since deletion also cancels all tasks for the source

  Returns {:ok, %Task{}} | {:error, %Ecto.Changeset{}}
  """
  def kickoff(source, job_args \\ %{}, job_opts \\ []) do
    %{id: source.id}
    |> Map.merge(job_args)
    |> SourceDeletionWorker.new(job_opts)
    |> Oban.insert()
  end

  @doc """
  Deletes a source and optionally deletes its files

  Returns :ok
  """
  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"id" => source_id} = args}) do
    delete_files = Map.get(args, "delete_files", false)
    source = Sources.get_source!(source_id)

    Sources.delete_source(source, delete_files: delete_files)
  end
end
