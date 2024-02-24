defmodule Pinchflat.MediaClient.Backends.YtDlp.MetadataFileHelpers do
  @moduledoc """
  Provides methods for creating/downloading/storing related metadata
  out-of-band of the normal yt-dlp backend process.

  The idea is that I don't want to craft a complicated yt-dlp command,
  instead focusing on downloading the video as the user wants it then
  I can use the result of that here to grab the additional information
  needed
  """

  # TODO: ensure media metadata is deleted when the media item is deleted

  @doc """
  Compresses and stores metadata for a media item, returning the filepath.

  Returns binary()
  """
  def compress_and_store_metadata_for(database_record, metadata_map) do
    filepath = generate_filepath_for(database_record, "metadata.json.gz")
    {:ok, json} = Phoenix.json_library().encode(metadata_map)

    File.mkdir_p!(Path.dirname(filepath))
    :ok = File.write(filepath, json, [:compressed])

    filepath
  end

  @doc """
  Reads and decodes compressed metadata from a filepath.

  Returns {:ok, map()} | {:error, any}
  """
  def read_compressed_metadata(filepath) do
    {:ok, json} = File.open(filepath, [:read, :compressed], &IO.read(&1, :all))

    Phoenix.json_library().decode(json)
  end

  @doc """
  Downloads and stores a thumbnail for a media item, returning the filepath.

  Returns binary()
  """
  def download_and_store_thumbnail_for(database_record, metadata_map) do
    thumbnail_url = metadata_map["thumbnail"]
    filepath = generate_filepath_for(database_record, Path.basename(thumbnail_url))
    thumbnail_blob = fetch_thumbnail_from_url(thumbnail_url)

    File.mkdir_p!(Path.dirname(filepath))
    :ok = File.write(filepath, thumbnail_blob)

    filepath
  end

  defp fetch_thumbnail_from_url(url) do
    http_client = Application.get_env(:pinchflat, :http_client, Pinchflat.HTTP.HTTPClient)
    {:ok, body} = http_client.get(url, [], body_format: :binary)

    body
  end

  defp generate_filepath_for(database_record, filename) do
    metadata_directory = Application.get_env(:pinchflat, :metadata_directory)
    record_table_name = database_record.__meta__.source

    Path.join([
      metadata_directory,
      record_table_name,
      to_string(database_record.id),
      filename
    ])
  end
end
