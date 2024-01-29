defmodule Pinchflat.MediaClient.Backends.YtDlp.Video do
  @moduledoc """
  Contains utilities for working with singular videos
  """

  alias Pinchflat.Utils.StringUtils

  @doc """
  Downloads a single video (and possible metadata) directly to its
  final destination. Returns the parsed JSON output from yt-dlp.

  It writes to file and then immediately reads from it since printing
  to stdout also contains any warnings/errors that may have occurred,
  even if the command is otherwise successful (which creates invalid
  JSON).

  Returns {:ok, map()} | {:error, any, ...}.

  TODO: test changes (writing to then reading from a file)
  """
  def download(url, command_opts \\ []) do
    json_output_path = Path.join([metadata_directory(), "#{StringUtils.random_string()}.json"])
    # These must stay in exactly this order, hence why I'm giving it its own variable.
    # Also, can't use RAM file since yt-dlp needs a concrete filepath.
    print_to_file_opts = [{:print_to_file, "after_move:%()j"}, json_output_path]
    opts = [:no_simulate] ++ print_to_file_opts ++ command_opts

    with {:ok, _} <- backend_runner().run(url, opts),
         {:ok, file_body} <- File.read(json_output_path),
         {:ok, parsed_json} <- Phoenix.json_library().decode(file_body) do
      {:ok, parsed_json}
    else
      err -> err
    end
  end

  defp backend_runner do
    Application.get_env(:pinchflat, :yt_dlp_runner)
  end

  defp metadata_directory do
    Application.get_env(:pinchflat, :metadata_directory)
  end
end
