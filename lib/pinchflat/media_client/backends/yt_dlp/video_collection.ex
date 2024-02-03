defmodule Pinchflat.MediaClient.Backends.YtDlp.VideoCollection do
  @moduledoc """
  Contains utilities for working with collections of
  videos (aka: a source [ie: channels, playlists]).
  """

  alias Pinchflat.MediaClient.SourceDetails

  @doc """
  Returns a list of strings representing the video ids in the collection.

  Returns {:ok, [binary()]} | {:error, any, ...}.
  """
  def get_video_ids(url, command_opts \\ []) do
    runner = Application.get_env(:pinchflat, :yt_dlp_runner)
    opts = command_opts ++ [:simulate, :skip_download]

    case runner.run(url, opts, "%(id)s") do
      {:ok, output} -> {:ok, String.split(output, "\n", trim: true)}
      res -> res
    end
  end

  @doc """
  Gets a source's ID and name from its URL.

  yt-dlp does not _really_ have source-specific functions, so
  instead we're fetching just the first video (using playlist_end: 1)
  and parsing the source ID and name from _its_ metadata

  Returns {:ok, %SourceDetails{}} | {:error, any, ...}.
  """
  def get_source_details(source_url) do
    opts = [:skip_download, playlist_end: 1]

    with {:ok, output} <- backend_runner().run(source_url, opts, "%(.{channel,channel_id})j"),
         {:ok, parsed_json} <- Phoenix.json_library().decode(output) do
      {:ok, SourceDetails.new(parsed_json["channel_id"], parsed_json["channel"])}
    else
      err -> err
    end
  end

  defp backend_runner do
    Application.get_env(:pinchflat, :yt_dlp_runner)
  end
end
