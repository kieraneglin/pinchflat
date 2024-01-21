defmodule Pinchflat.Downloader.Backends.YtDlp.Video do
  @moduledoc """
  Contains utilities for working with singular videos
  """

  @doc """
  Downloads a single video (and possible metadata) to the tmp directory.
  Videos are downloaded in the following format:
    `tmp/yt-dlp/<video_id>/<video_id>.<ext>`

  The video will be moved to its final destination... elsewhere
  # TODO: update these docs when I figure out a module to move videos
  # TODO: test
  # NOTE: maybe instead of moving it to the tempdir, I can just download it
          to the final destination by using the `output` option. The
          parser could be updated to generate a value for the output option.
          This way, advanced users can just the yt-dlp output syntax and
          newer users can use the easier liquid-like syntax.
  """
  def download(url, command_opts \\ []) do
    # TODO: if this stays this simple, consider not abstracting it
    #       HOWEVER - this module does provide clarity of intent so maybe keep?
    backend_runner().run(url, command_opts)
  end

  defp backend_runner do
    Application.get_env(:pinchflat, :yt_dlp_runner)
  end
end
