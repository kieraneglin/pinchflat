defmodule Pinchflat.YtDlp.Media do
  @moduledoc """
  Contains utilities for working with singular pieces of media
  """

  @enforce_keys [
    :media_id,
    :title,
    :description,
    :original_url,
    :livestream,
    :short_form_content,
    :uploaded_at,
    :duration_seconds
  ]

  defstruct [
    :media_id,
    :title,
    :description,
    :original_url,
    :livestream,
    :short_form_content,
    :uploaded_at,
    :duration_seconds,
    :playlist_index
  ]

  alias __MODULE__
  alias Pinchflat.Utils.FunctionUtils
  alias Pinchflat.Metadata.MetadataFileHelpers

  @doc """
  Downloads a single piece of media (and possibly its metadata) directly to its
  final destination. Returns the parsed JSON output from yt-dlp.

  Returns {:ok, map()} | {:error, any, ...}.
  """
  def download(url, command_opts \\ [], addl_opts \\ []) do
    opts = [:no_simulate] ++ command_opts

    with {:ok, output} <- backend_runner().run(url, opts, "after_move:%()j", addl_opts),
         {:ok, parsed_json} <- Phoenix.json_library().decode(output) do
      {:ok, parsed_json}
    else
      err -> err
    end
  end

  @doc """
  Downloads a thumbnail for a single piece of media. Usually used for
  downloading thumbnails for internal use

  Returns {:ok, ""} | {:error, any, ...}.
  """
  def download_thumbnail(url, command_opts \\ [], addl_opts \\ []) do
    all_command_opts = [:no_simulate, :skip_download, :write_thumbnail, convert_thumbnail: "jpg"] ++ command_opts

    # NOTE: it doesn't seem like this command actually returns anything in `after_move` since
    # we aren't downloading the main media file
    # TODO: test
    backend_runner().run(url, all_command_opts, "after_move:%()j", addl_opts)
  end

  @doc """
  Returns a map representing the media at the given URL.

  Returns {:ok, %Media{}} | {:error, any, ...}.
  """
  def get_media_attributes(url, addl_opts \\ []) do
    runner = Application.get_env(:pinchflat, :yt_dlp_runner)
    command_opts = [:simulate, :skip_download]
    output_template = indexing_output_template()

    # TODO: test
    case runner.run(url, command_opts, output_template, addl_opts) do
      {:ok, output} ->
        output
        |> Phoenix.json_library().decode!()
        |> response_to_struct()
        |> FunctionUtils.wrap_ok()

      err ->
        err
    end
  end

  @doc """
  Returns the output template for yt-dlp's indexing command.

  NOTE: playlist_index is really only useful for playlists that will never change their order.
  """
  def indexing_output_template do
    "%(.{id,title,was_live,webpage_url,description,aspect_ratio,duration,upload_date,timestamp,playlist_index})j"
  end

  @doc """
  Transforms a response from yt-dlp into a struct. Interprets the response to
  determine if the media is short-form content.

  Returns %Media{}.
  """
  def response_to_struct(response) do
    %Media{
      media_id: response["id"],
      title: response["title"],
      description: response["description"],
      original_url: response["webpage_url"],
      livestream: !!response["was_live"],
      duration_seconds: response["duration"] && round(response["duration"]),
      short_form_content: response["webpage_url"] && short_form_content?(response),
      uploaded_at: response["upload_date"] && parse_uploaded_at(response),
      playlist_index: response["playlist_index"] || 0
    }
  end

  defp short_form_content?(response) do
    if String.contains?(response["webpage_url"], "/shorts/") do
      true
    else
      # Sometimes shorts are returned without /shorts/ in the URL,
      # so we need to do our best to determine if it's a short. This
      # WILL returns false positives, but it's a best-effort approach
      # that should work for most cases. The aspect_ratio check is
      # based on a gut feeling and may need to be tweaked.
      #
      # These don't fail if duration or aspect_ratio are missing
      # due to Elixir's comparison semantics
      response["duration"] <= 60 && response["aspect_ratio"] < 0.8
    end
  end

  defp parse_uploaded_at(%{"timestamp" => ts} = response) when is_number(ts) do
    case DateTime.from_unix(ts) do
      {:ok, datetime} -> datetime
      _ -> MetadataFileHelpers.parse_upload_date(response["upload_date"])
    end
  end

  # This field is needed before inserting into the database, but absence
  # of this field should fail at insert-time rather than here
  defp parse_uploaded_at(%{"upload_date" => nil}), do: nil
  defp parse_uploaded_at(response), do: MetadataFileHelpers.parse_upload_date(response["upload_date"])

  defp backend_runner do
    # This approach lets us mock the command for testing
    Application.get_env(:pinchflat, :yt_dlp_runner)
  end
end
