defmodule Pinchflat.YtDlp.Backend.Media do
  @moduledoc """
  Contains utilities for working with singular pieces of media
  """

  defstruct [
    :media_id,
    :title,
    :description,
    :original_url,
    :livestream
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
    "%(.{id,title,was_live,original_url,description})j"
  end

  # TODO: test
  def response_to_struct(response) do
    %Media{
      media_id: response["id"],
      title: response["title"],
      description: response["description"],
      original_url: response["original_url"],
      livestream: response["was_live"]
    }
  end

  defp backend_runner do
    # This approach lets us mock the command for testing
    Application.get_env(:pinchflat, :yt_dlp_runner)
  end
end
