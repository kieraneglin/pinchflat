defmodule Pinchflat.Metadata.MetadataFileHelpers do
  @moduledoc """
  Provides methods for creating/downloading/storing related metadata
  out-of-band of the normal yt-dlp backend process.

  The idea is that I don't want to craft a complicated yt-dlp command,
  instead focusing on downloading the media as the user wants it then
  I can use the result of that here to grab the additional information
  needed
  """

  alias Pinchflat.Utils.FilesystemUtils

  alias Pinchflat.YtDlp.Media, as: YtDlpMedia

  @doc """
  Returns the directory where metadata for a database record should be stored.

  Returns binary()
  """
  def metadata_directory_for(database_record) do
    metadata_directory = Application.get_env(:pinchflat, :metadata_directory)
    record_table_name = database_record.__meta__.source

    Path.join([
      metadata_directory,
      record_table_name,
      to_string(database_record.id)
    ])
  end

  @doc """
  Compresses and stores metadata for a media item, returning the filepath.

  Returns binary()
  """
  def compress_and_store_metadata_for(database_record, metadata_map) do
    filepath = generate_filepath_for(database_record, "metadata.json.gz")
    {:ok, json} = Phoenix.json_library().encode(metadata_map)

    :ok = FilesystemUtils.write_p!(filepath, json, [:compressed])

    filepath
  end

  @doc """
  Reads and decodes compressed metadata from a filepath.

  Returns {:ok, map()} | {:error, any}
  """
  def read_compressed_metadata(filepath) do
    {:ok, json} = File.open(filepath, [:read, :compressed], &IO.read(&1, :eof))

    Phoenix.json_library().decode(json)
  end

  @doc """
  Downloads and stores a thumbnail for a media item, returning the filepath.
  Chooses the highest quality thumbnail available and converts it to a JPG

  Returns nil if no thumbnail is available or if yt-dlp encounters an error

  Returns binary() | nil
  """
  def download_and_store_thumbnail_for(media_item_with_preloads) do
    yt_dlp_filepath = generate_filepath_for(media_item_with_preloads, "thumbnail.%(ext)s")
    real_filepath = generate_filepath_for(media_item_with_preloads, "thumbnail.jpg")
    command_opts = [output: yt_dlp_filepath]
    addl_opts = [use_cookies: media_item_with_preloads.source.use_cookies]

    # TODO: test
    case YtDlpMedia.download_thumbnail(media_item_with_preloads.original_url, command_opts, addl_opts) do
      {:ok, _} -> real_filepath
      _ -> nil
    end
  end

  @doc """
  Parses an upload date from the YYYYMMDD string returned in yt-dlp metadata
  and returns a DateTime struct, appending a time of 00:00:00Z.

  Returns DateTime.t()
  """
  def parse_upload_date(upload_date) do
    <<year::binary-size(4)>> <> <<month::binary-size(2)>> <> <<day::binary-size(2)>> = upload_date

    case DateTime.from_iso8601("#{year}-#{month}-#{day}T00:00:00Z") do
      {:ok, datetime, _} -> datetime
      _ -> raise "Invalid upload date: #{upload_date}"
    end
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

  @doc """
  Attempts to determine the season and episode number from a media filepath.

  Returns {:ok, {binary(), binary()}} | {:error, :indeterminable}
  """
  def season_and_episode_from_media_filepath(media_filepath) do
    # matches s + 1 or more digits + e + 1 or more digits (case-insensitive)
    season_episode_regex = ~r/s(\d+)e(\d+)/i

    case Regex.scan(season_episode_regex, media_filepath) do
      [[_, season, episode] | _] -> {:ok, {season, episode}}
      _ -> {:error, :indeterminable}
    end
  end

  defp generate_filepath_for(database_record, filename) do
    Path.join([
      metadata_directory_for(database_record),
      filename
    ])
  end
end
