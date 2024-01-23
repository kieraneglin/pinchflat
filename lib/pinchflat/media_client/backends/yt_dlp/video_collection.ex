defmodule Pinchflat.MediaClient.Backends.YtDlp.VideoCollection do
  @moduledoc """
  Contains utilities for working with collections of videos (ie: channels, playlists).

  Meant to be included in other modules but can be used on its own. Channels and playlists
  will have many of their own methods, but also share a lot of methods. This module is for
  those shared methods.
  """

  defmacro __using__(_) do
    quote do
      @doc """
      Returns a list of strings representing the video ids in the collection.

      Returns {:ok, [binary()]} | {:error, any, ...}.
      """
      def get_video_ids(url, command_opts \\ []) do
        runner = Application.get_env(:pinchflat, :yt_dlp_runner)
        opts = command_opts ++ [:simulate, :skip_download, print: :id]

        case runner.run(url, opts) do
          {:ok, output} -> {:ok, String.split(output, "\n", trim: true)}
          res -> res
        end
      end
    end
  end
end
