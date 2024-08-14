defmodule Pinchflat.YtDlp.MediaCollection do
  @moduledoc """
  Contains utilities for working with collections of
  media (aka: a source [ie: channels, playlists]).
  """

  require Logger

  alias Pinchflat.Utils.FilesystemUtils
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
    # `ignore_no_formats_error` is necessary because yt-dlp will error out if
    # the first video has not released yet (ie: is a premier). We don't care about
    # available formats since we're just getting the media details
    command_opts = [:simulate, :skip_download, :ignore_no_formats_error, :no_warnings]
    use_cookies = Keyword.get(addl_opts, :use_cookies, false)
    output_template = YtDlpMedia.indexing_output_template()
    output_filepath = FilesystemUtils.generate_metadata_tmpfile(:json)
    file_listener_handler = Keyword.get(addl_opts, :file_listener_handler, false)
    # TODO: test
    runner_opts = [output_filepath: output_filepath, use_cookies: use_cookies]

    if file_listener_handler do
      file_listener_handler.(output_filepath)
    end

    case runner.run(url, command_opts, output_template, runner_opts) do
      {:ok, output} ->
        parsed_lines =
          output
          |> String.split("\n", trim: true)
          |> Enum.map(fn line ->
            case Phoenix.json_library().decode(line) do
              {:ok, parsed_json} ->
                YtDlpMedia.response_to_struct(parsed_json)

              _ ->
                nil
            end
          end)

        {:ok, Enum.filter(parsed_lines, &(&1 != nil))}

      err ->
        err
    end
  end

  @doc """
  Gets a source's ID and name from its URL.

  yt-dlp does not _really_ have source-specific functions that return what
  we need, so instead we're fetching just the first video (using playlist_end: 1)
  and parsing the source ID and name from _its_ metadata

  Returns {:ok, map()} | {:error, any, ...}.
  """
  def get_source_details(source_url, command_opts \\ [], addl_opts \\ []) do
    # `ignore_no_formats_error` is necessary because yt-dlp will error out if
    # the first video has not released yet (ie: is a premier). We don't care about
    # available formats since we're just getting the source details
    default_opts = [
      :simulate,
      :skip_download,
      :ignore_no_formats_error,
      playlist_end: 1
    ]

    all_command_opts = default_opts ++ command_opts
    output_template = "%(.{channel,channel_id,playlist_id,playlist_title,filename})j"

    # TODO: test
    with {:ok, output} <- backend_runner().run(source_url, all_command_opts, output_template, addl_opts),
         {:ok, parsed_json} <- Phoenix.json_library().decode(output) do
      {:ok, format_source_details(parsed_json)}
    else
      err -> err
    end
  end

  @doc """
  Gets a source's metadata from its URL.

  This is mostly for things like getting the source's avatar and banner image
  (if applicable). However, this yt-dlp call doesn't have enough overlap with
  `get_source_details/1` to allow combining them - this one has _almost_ everything
  we need, but it doesn't contain enough information to tell 100% if the url is a channel
  or a playlist.

  The main purpose of this (past using as a fetcher for _other_ metadata) is to live
  as a compressed blob for possible future use. That's why it's not getting formatted like
  `get_source_details/1`

  ! IMPORTANT ! - you'll always want to set `playlist_items: int` in `addl_opts.
  This is great if you want to also return details about the videos in the playlists,
  but it should be set in all cases to not over-fetch data.
  For channels you should usually set this to 0 since channels return all the
  metadata we need without needing to fetch the videos. On the other hand, playlists
  don't return very useful images so you can set this to 1 to get the first video's
  images, for instance.

  Returns {:ok, map()} | {:error, any, ...}.
  """
  def get_source_metadata(source_url, command_opts \\ [playlist_items: 0], addl_opts \\ []) do
    # This only validates that the `playlist_items` key is present. It's otherwise unused
    _playlist_items = Keyword.fetch!(command_opts, :playlist_items)

    all_command_opts = [:skip_download] ++ command_opts
    output_template = "playlist:%()j"

    # TODO: test
    with {:ok, output} <- backend_runner().run(source_url, all_command_opts, output_template, addl_opts),
         {:ok, parsed_json} <- Phoenix.json_library().decode(output) do
      {:ok, parsed_json}
    else
      err -> err
    end
  end

  defp format_source_details(response) do
    # NOTE: I should probably make this a struct some day
    %{
      channel_id: response["channel_id"],
      channel_name: response["channel"],
      playlist_id: response["playlist_id"],
      playlist_name: response["playlist_title"],
      # It's not a name, it's a path dammit!
      # This actually isn't used for the inital response - it's
      # used later to update a source's metadata
      filepath: response["filename"]
    }
  end

  defp backend_runner do
    # This approach lets us mock the command for testing
    Application.get_env(:pinchflat, :yt_dlp_runner)
  end
end
