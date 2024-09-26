defmodule Pinchflat.Media.FileSyncingWorker do
  @moduledoc false

  use Oban.Worker,
    queue: :local_data,
    tags: ["sources", "local_data"]

  alias __MODULE__
  alias Pinchflat.Repo
  alias Pinchflat.Tasks
  alias Pinchflat.Sources
  alias Pinchflat.Media.FileSyncing

  @doc """
  Starts the source file syncing worker.

  Returns {:ok, %Task{}} | {:error, %Ecto.Changeset{}}
  """
  def kickoff_with_task(source, opts \\ []) do
    %{id: source.id}
    |> FileSyncingWorker.new(opts)
    |> Tasks.create_job_with_task(source)
  end

  @doc """
  Deletes a profile and optionally deletes its files

  Returns :ok
  """
  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"id" => source_id}}) do
    source = Repo.preload(Sources.get_source!(source_id), :media_items)

    FileSyncing.sync_file_presence_on_disk(source.media_items)

    :ok
  end
end
