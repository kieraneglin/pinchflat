defmodule Pinchflat.Metadata.SourceMetadataStorageWorker do
  @moduledoc false

  use Oban.Worker,
    queue: :remote_metadata,
    tags: ["media_source", "source_metadata", "remote_metadata"],
    max_attempts: 1,
    # This is the only thing stopping this job from calling itself
    # in an infinite loop.
    unique: [period: 600]

  require Logger

  alias __MODULE__
  alias Pinchflat.Repo
  alias Pinchflat.Tasks
  alias Pinchflat.Sources
  alias Pinchflat.YtDlp.MediaCollection
  alias Pinchflat.Metadata.MetadataFileHelpers

  @doc """
  Starts the source metadata storage worker and creates a task for the source.

  Returns {:ok, %Task{}} | {:error, :duplicate_job} | {:error, %Ecto.Changeset{}}
  """
  def kickoff_with_task(source, opts \\ []) do
    %{id: source.id}
    |> SourceMetadataStorageWorker.new(opts)
    |> Tasks.create_job_with_task(source)
  end

  @doc """
  Fetches and stores metadata for a source in the secret metadata location.

  Returns :ok
  """
  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"id" => source_id}}) do
    source = Repo.preload(Sources.get_source!(source_id), :metadata)
    {:ok, metadata} = MediaCollection.get_source_metadata(source.original_url)

    # Since updating a source kicks this job off again, we enforce job uniqueness (above)
    # to once, per source, per x minutes. This is to prevent a job from calling itself
    # in an infinite loop.
    Sources.update_source(source, %{
      metadata: %{
        metadata_filepath: MetadataFileHelpers.compress_and_store_metadata_for(source, metadata)
      }
    })

    :ok
  rescue
    Ecto.NoResultsError -> Logger.info("#{__MODULE__} discarded: source #{source_id} not found")
    Ecto.StaleEntryError -> Logger.info("#{__MODULE__} discarded: source #{source_id} stale")
  end
end
