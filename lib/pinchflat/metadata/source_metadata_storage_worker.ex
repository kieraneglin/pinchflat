defmodule Pinchflat.Metadata.SourceMetadataStorageWorker do
  @moduledoc false

  use Oban.Worker,
    queue: :remote_metadata,
    tags: ["media_source", "source_metadata", "remote_metadata"],
    max_attempts: 1,
    # This is the only thing stopping this job from calling itself
    # in an infinite loop. Time is in seconds
    unique: [period: 120]

  require Logger

  alias __MODULE__
  alias Pinchflat.Repo
  alias Pinchflat.Tasks
  alias Pinchflat.Sources
  alias Pinchflat.YtDlp.MediaCollection
  alias Pinchflat.Metadata.MetadataFileHelpers
  alias Pinchflat.Downloading.DownloadOptionBuilder

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
  Fetches and stores various forms of metadata for a source:
    - JSON metadata for internal use
    - The series directory for the source
    - The NFO file for the source (if specified)

  Returns :ok
  """
  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"id" => source_id}}) do
    source = Repo.preload(Sources.get_source!(source_id), [:metadata, :media_profile])
    series_directory = determine_series_directory(source)

    # Since updating a source kicks this job off again, we enforce job uniqueness (above)
    # to once, per source, per x minutes. This is to prevent a job from calling itself
    # in an infinite loop.
    Sources.update_source(source, %{
      series_directory: series_directory,
      metadata: %{
        metadata_filepath: store_source_metadata(source)
      }
    })

    :ok
  rescue
    Ecto.NoResultsError -> Logger.info("#{__MODULE__} discarded: source #{source_id} not found")
    Ecto.StaleEntryError -> Logger.info("#{__MODULE__} discarded: source #{source_id} stale")
  end

  defp store_source_metadata(source) do
    {:ok, metadata} = MediaCollection.get_source_metadata(source.original_url)

    MetadataFileHelpers.compress_and_store_metadata_for(source, metadata)
  end

  defp determine_series_directory(source) do
    output_path = DownloadOptionBuilder.build_output_path_for(source)
    {:ok, %{filepath: filepath}} = MediaCollection.get_source_details(source.original_url, output: output_path)

    case MetadataFileHelpers.series_directory_from_media_filepath(filepath) do
      {:ok, series_directory} -> series_directory
      {:error, _} -> nil
    end
  end
end
