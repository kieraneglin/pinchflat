defmodule Pinchflat.Metadata.SourceMetadataStorageWorker do
  @moduledoc false

  use Oban.Worker,
    queue: :remote_metadata,
    tags: ["media_source", "source_metadata", "remote_metadata"],
    max_attempts: 1

  alias __MODULE__
  alias Pinchflat.Repo
  alias Pinchflat.Tasks
  alias Pinchflat.Sources
  alias Pinchflat.YtDlp.MediaCollection
  alias Pinchflat.Metadata.MetadataFileHelpers

  @doc """
  Starts the source metadata storage worker and creates a task for the source.

  IDEA: testing out this method of handling job kickoff. I think I like it, so
  I may use it in other places. Just testing it for now

  Returns {:ok, %Task{}} | {:error, :duplicate_job} | {:error, %Ecto.Changeset{}}
  """
  def kickoff_with_task(source) do
    %{id: source.id}
    |> SourceMetadataStorageWorker.new()
    |> Tasks.create_job_with_task(source)
  end

  @impl Oban.Worker
  @doc """
  Fetches and stores metadata for a source in the secret metadata location.

  Returns :ok
  """
  def perform(%Oban.Job{args: %{"id" => source_id}}) do
    source = Repo.preload(Sources.get_source!(source_id), :metadata)
    {:ok, metadata} = MediaCollection.get_source_metadata(source.original_url)

    Sources.update_source(source, %{
      metadata: %{
        metadata_filepath: MetadataFileHelpers.compress_and_store_metadata_for(source, metadata)
      }
    })

    :ok
  end
end
