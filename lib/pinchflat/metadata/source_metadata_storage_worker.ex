defmodule Pinchflat.Metadata.SourceMetadataStorageWorker do
  @moduledoc false

  use Oban.Worker,
    queue: :remote_metadata,
    tags: ["media_source", "source_metadata", "remote_metadata", "show_in_dashboard"],
    max_attempts: 3

  require Logger

  alias __MODULE__
  alias Pinchflat.Repo
  alias Pinchflat.Tasks
  alias Pinchflat.Sources
  alias Pinchflat.Utils.StringUtils
  alias Pinchflat.Metadata.NfoBuilder
  alias Pinchflat.YtDlp.MediaCollection
  alias Pinchflat.Metadata.SourceImageParser
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
    - Attributes like `description`
    - JSON metadata for internal use
    - The series directory for the source
    - The NFO file for the source (if specified)
    - Downloads and stores source images (if specified)

  The worker is kicked off after a source is inserted or it's original_url
  is updated - this can take an unknown amount of time so don't rely on this
  data being here before, say, the first indexing or downloading task is complete.

  Returns :ok
  """
  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"id" => source_id}}) do
    source = Repo.preload(Sources.get_source!(source_id), [:metadata, :media_profile])
    series_directory = determine_series_directory(source)

    {source_metadata, source_image_attrs, metadata_image_attrs} =
      fetch_source_metadata_and_images(series_directory, source)

    source_metadata_filepath = MetadataFileHelpers.compress_and_store_metadata_for(source, source_metadata)

    Sources.update_source(
      source,
      Map.merge(
        %{
          series_directory: series_directory,
          nfo_filepath: store_source_nfo(source, series_directory, source_metadata),
          description: source_metadata["description"],
          metadata: Map.merge(%{metadata_filepath: source_metadata_filepath}, metadata_image_attrs)
        },
        source_image_attrs
      ),
      # `run_post_commit_tasks: false` prevents this from running in an infinite loop
      run_post_commit_tasks: false
    )

    :ok
  rescue
    Ecto.NoResultsError -> Logger.info("#{__MODULE__} discarded: source #{source_id} not found")
    Ecto.StaleEntryError -> Logger.info("#{__MODULE__} discarded: source #{source_id} stale")
  end

  defp fetch_source_metadata_and_images(series_directory, source) do
    metadata_directory = MetadataFileHelpers.metadata_directory_for(source)
    # TODO: test
    {:ok, metadata} = fetch_metadata_for_source(source)
    metadata_image_attrs = SourceImageParser.store_source_images(metadata_directory, metadata)

    if source.media_profile.download_source_images && series_directory do
      source_image_attrs = SourceImageParser.store_source_images(series_directory, metadata)

      {metadata, source_image_attrs, metadata_image_attrs}
    else
      {metadata, %{}, metadata_image_attrs}
    end
  end

  defp determine_series_directory(source) do
    output_path = DownloadOptionBuilder.build_output_path_for(source)
    {:ok, %{filepath: filepath}} = MediaCollection.get_source_details(source.original_url, output: output_path)

    case MetadataFileHelpers.series_directory_from_media_filepath(filepath) do
      {:ok, series_directory} -> series_directory
      {:error, _} -> nil
    end
  end

  defp store_source_nfo(source, series_directory, metadata) do
    if source.media_profile.download_nfo && series_directory do
      nfo_filepath = Path.join(series_directory, "tvshow.nfo")

      NfoBuilder.build_and_store_for_source(nfo_filepath, metadata)
    end
  end

  defp fetch_metadata_for_source(source) do
    # TODO: test
    tmp_output_path = "#{tmp_directory()}/#{StringUtils.random_string(16)}/source_image.%(ext)S"
    base_opts = [convert_thumbnails: "jpg", output: tmp_output_path]

    opts =
      if source.collection_type == :channel do
        base_opts ++ [:write_all_thumbnails, playlist_items: 0]
      else
        base_opts ++ [:write_thumbnails, playlist_items: 1]
      end

    MediaCollection.get_source_metadata(source.original_url, opts)
  end

  defp tmp_directory do
    Application.get_env(:pinchflat, :tmpfile_directory)
  end
end
