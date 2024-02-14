defmodule Pinchflat.MediaClient.Backends.YtDlp.VideoCollection do
  @moduledoc """
  Contains utilities for working with collections of
  videos (aka: a source [ie: channels, playlists]).
  """

  alias Pinchflat.Utils.FunctionUtils

  @doc """
  Returns a list of maps representing the videos in the collection.

  Returns {:ok, [map()]} | {:error, any, ...}.
  """
  def get_media_attributes(url, command_opts \\ []) do
    runner = Application.get_env(:pinchflat, :yt_dlp_runner)
    opts = command_opts ++ [:simulate, :skip_download]
    output_template = "%(.{id,title,was_live,original_url,description})j"

    case runner.run(url, opts, output_template) do
      {:ok, output} ->
        output
        |> String.split("\n", trim: true)
        |> Enum.map(&Phoenix.json_library().decode!/1)
        |> FunctionUtils.wrap_ok()

      res ->
        res
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
