defmodule Pinchflat.Metadata.MetadataFileHelpers do
  @moduledoc """
  Provides methods for creating/downloading/storing related metadata
  out-of-band of the normal yt-dlp backend process.

  The idea is that I don't want to craft a complicated yt-dlp command,
  instead focusing on downloading the media as the user wants it then
  I can use the result of that here to grab the additional information
  needed
  """

  alias Pinchflat.Filesystem.FilesystemHelpers

  @doc """
  Compresses and stores metadata for a media item, returning the filepath.

  Returns binary()
  """
  def compress_and_store_metadata_for(database_record, metadata_map) do
    filepath = generate_filepath_for(database_record, "metadata.json.gz")
    {:ok, json} = Phoenix.json_library().encode(metadata_map)

    :ok = FilesystemHelpers.write_p!(filepath, json, [:compressed])

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

    :ok = FilesystemHelpers.write_p!(filepath, thumbnail_blob)

    filepath
  end

  @doc """
  Parses an upload date from the YYYYMMDD string returned in yt-dlp metadata
  and returns a Date struct.

  Returns Date.t()
  """
  def parse_upload_date(upload_date) do
    <<year::binary-size(4)>> <> <<month::binary-size(2)>> <> <<day::binary-size(2)>> = upload_date

    Date.from_iso8601!("#{year}-#{month}-#{day}")
  end

  @doc """
  Attempts to determine the series directory from a media filepath.
  The series directory is the "root" directory for a given source
  which should contain all the season-level folders of that source.

  Used for determining where to store things like NFO data and banners
  for media center apps. Not useful without a media center app.

  Returns {:ok, binary()} | {:error, :indeterminable}
  """
  def series_directory_from_media_filepath(media_filepath) do
    # Matches "s" or "season" (case-insensitive)
    # followed by an optional non-word character (. or _ or <space>, etc)
    # followed by at least one digit
    # followed immediately by the end of the string
    # Example matches: s1, s.1, s01 season 1, Season.01, Season_1, Season 1, Season1
    # Example non-matches: s01e01, season, series 1,
    season_regex = ~r/^s(eason)?(\W|_)?\d{1,}$/i

    {series_directory, found_series_directory} =
      media_filepath
      |> Path.split()
      |> Enum.reduce_while({[], false}, fn part, {directory_acc, _} ->
        if String.match?(part, season_regex) do
          {:halt, {directory_acc, true}}
        else
          {:cont, {directory_acc ++ [part], false}}
        end
      end)

    if found_series_directory do
      {:ok, Path.join(series_directory)}
    else
      {:error, :indeterminable}
    end
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
