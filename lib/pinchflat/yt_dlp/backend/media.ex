defmodule Pinchflat.YtDlp.Backend.Media do
  @moduledoc """
  Contains utilities for working with singular pieces of media
  """

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

  IDEA: should I return a struct here? I want these methods to be agnostic
  to implementation, but maybe it can specify its own contract by
  returning a struct with well-known fields. Would make refactoring
  turbo easy if a field needs to exist but its behavior changes slightly.

  Returns {:ok, [map()]} | {:error, any, ...}.
  """
  def get_media_attributes(url) do
    runner = Application.get_env(:pinchflat, :yt_dlp_runner)
    command_opts = [:simulate, :skip_download]
    output_template = indexing_output_template()

    case runner.run(url, command_opts, output_template) do
      {:ok, output} -> Phoenix.json_library().decode(output)
      res -> res
    end
  end

  @doc """
  Returns the output template for yt-dlp's indexing command.
  """
  def indexing_output_template do
    "%(.{id,title,was_live,original_url,description})j"
  end

  defp backend_runner do
    # This approach lets us mock the command for testing
    Application.get_env(:pinchflat, :yt_dlp_runner)
  end
end
