defmodule Pinchflat.MediaClient.Backends.YtDlp.VideoCollection do
  @moduledoc """
  Contains utilities for working with collections of
  videos (aka: a source [ie: channels, playlists]).
  """

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

  Returns {:ok, map()} | {:error, any, ...}.
  """
  def get_source_details(source_url) do
    opts = [:simulate, :skip_download, playlist_end: 1]
    output_template = "%(.{channel,channel_id,playlist_id,playlist_title})j"

    with {:ok, output} <- backend_runner().run(source_url, opts, output_template),
         {:ok, parsed_json} <- Phoenix.json_library().decode(output) do
      {:ok, format_source_details(parsed_json)}
    else
      err -> err
    end
  end

  # TODO: test
  defp format_source_details(response) do
    %{
      channel_id: response["channel_id"],
      channel_name: response["channel"],
      playlist_id: response["playlist_id"],
      playlist_name: response["playlist_title"]
    }
  end

  defp backend_runner do
    Application.get_env(:pinchflat, :yt_dlp_runner)
  end
end
