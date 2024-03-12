defmodule Pinchflat.FastIndexing.YoutubeRss do
  @moduledoc """
  Methods for interacting with YouTube RSS feeds
  """

  require Logger

  alias Pinchflat.Sources.Source

  @doc """
  Fetches the recent media IDs from a YouTube RSS feed for a given source.

  Returns {:ok, [binary()]} | {:error, binary()}
  """
  def get_recent_media_ids_from_rss(%Source{} = source) do
    Logger.debug("Fetching recent media IDs from YouTube RSS feed for source: #{source.collection_id}")

    case http_client().get(rss_url_for_source(source)) do
      {:ok, response} ->
        response = to_string(response)
        media_id_regex = ~r/<yt:videoId>(.*?)<\/yt:videoId>/

        # Don't get on me about using regex to search XML.
        # The content is known, well-formed, and simple.
        media_ids =
          media_id_regex
          |> Regex.scan(response)
          |> Enum.map(fn [_, id] -> String.trim(id) end)
          |> Enum.filter(&(String.length(&1) > 0))
          |> Enum.uniq()

        Logger.debug("Media ids fetched from RSS: #{inspect(media_ids)}")

        {:ok, media_ids}

      {:error, _reason} ->
        {:error, "Failed to fetch RSS feed"}
    end
  end

  defp rss_url_for_source(source) do
    case source.collection_type do
      :channel -> "https://www.youtube.com/feeds/videos.xml?channel_id=#{source.collection_id}"
      :playlist -> "https://www.youtube.com/feeds/videos.xml?playlist_id=#{source.collection_id}"
    end
  end

  defp http_client do
    Application.get_env(:pinchflat, :http_client, Pinchflat.HTTP.HTTPClient)
  end
end
