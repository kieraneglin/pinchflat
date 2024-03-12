defmodule Pinchflat.YtDlp.MediaCollection do
  @moduledoc """
  Contains utilities for working with collections of
  media (aka: a source [ie: channels, playlists]).
  """

  require Logger

  alias Pinchflat.Utils.FunctionUtils
  alias Pinchflat.Filesystem.FilesystemHelpers
  alias Pinchflat.YtDlp.Media, as: YtDlpMedia

  @doc """
  Returns a list of maps representing the media in the collection.

  Options:
    - :file_listener_handler - a function that will be called with the path to the
      file that will be written to when yt-dlp is done. This is useful for
      setting up a file watcher to know when the file is ready to be read.

  Returns {:ok, [map()]} | {:error, any, ...}.
  """
  def get_media_attributes_for_collection(url, addl_opts \\ []) do
    runner = Application.get_env(:pinchflat, :yt_dlp_runner)
    command_opts = [:simulate, :skip_download]
    output_template = YtDlpMedia.indexing_output_template()
    output_filepath = FilesystemHelpers.generate_metadata_tmpfile(:json)
    file_listener_handler = Keyword.get(addl_opts, :file_listener_handler, false)

    if file_listener_handler do
      file_listener_handler.(output_filepath)
    end

    case runner.run(url, command_opts, output_template, output_filepath: output_filepath) do
      {:ok, output} ->
        output
        |> String.split("\n", trim: true)
        |> Enum.map(&Phoenix.json_library().decode!/1)
        |> Enum.map(&YtDlpMedia.response_to_struct/1)
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
    # This approach lets us mock the command for testing
    Application.get_env(:pinchflat, :yt_dlp_runner)
  end
end
