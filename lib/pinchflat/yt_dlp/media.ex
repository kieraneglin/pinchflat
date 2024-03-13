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
    :upload_date
  ]

  defstruct [
    :media_id,
    :title,
    :description,
    :original_url,
    :livestream,
    :short_form_content,
    :upload_date
  ]

  alias __MODULE__
  alias Pinchflat.Utils.FunctionUtils

  @doc """
  Downloads a single piece of media (and possibly its metadata) directly to its
  final destination. Returns the parsed JSON output from yt-dlp.

  Returns {:ok, map()} | {:error, any, ...}.
  """
  def download(url, command_opts \\ []) do
    opts = [:no_simulate] ++ command_opts

    with {:ok, output} <- backend_runner().run(url, opts, "after_move:%()j"),
         {:ok, parsed_json} <- Phoenix.json_library().decode(output) do
      {:ok, parsed_json}
    else
      err -> err
    end
  end

  @doc """
  Returns a map representing the media at the given URL.

  Returns {:ok, [map()]} | {:error, any, ...}.
  """
  def get_media_attributes(url) do
    runner = Application.get_env(:pinchflat, :yt_dlp_runner)
    command_opts = [:simulate, :skip_download]
    output_template = indexing_output_template()

    case runner.run(url, command_opts, output_template) do
      {:ok, output} ->
        output
        |> Phoenix.json_library().decode!()
        |> response_to_struct()
        |> FunctionUtils.wrap_ok()

      res ->
        res
    end
  end

  @doc """
  Returns the output template for yt-dlp's indexing command.
  """
  def indexing_output_template do
    "%(.{id,title,was_live,webpage_url,description,aspect_ratio,duration,upload_date})j"
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
      livestream: response["was_live"],
      short_form_content: short_form_content?(response),
      upload_date: parse_upload_date(response["upload_date"])
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
      response["duration"] <= 60 && response["aspect_ratio"] < 0.8
    end
  end

  defp parse_upload_date(upload_date) do
    <<year::binary-size(4)>> <> <<month::binary-size(2)>> <> <<day::binary-size(2)>> = upload_date

    Date.from_iso8601!("#{year}-#{month}-#{day}")
  end

  defp backend_runner do
    # This approach lets us mock the command for testing
    Application.get_env(:pinchflat, :yt_dlp_runner)
  end
end
