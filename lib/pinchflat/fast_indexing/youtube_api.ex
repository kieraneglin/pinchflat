defmodule Pinchflat.FastIndexing.YoutubeApi do
  @moduledoc """
  Methods for interacting with the YouTube API for fast indexing
  """

  require Logger

  alias Pinchflat.Settings
  alias Pinchflat.Sources.Source
  alias Pinchflat.Utils.FunctionUtils
  alias Pinchflat.FastIndexing.YoutubeBehaviour

  @behaviour YoutubeBehaviour

  @doc """
  Determines if the YouTube API is enabled for fast indexing by checking
  if the user has an API key set

  Returns boolean()
  """
  @impl YoutubeBehaviour
  def enabled?(), do: is_binary(api_key())

  @doc """
  Fetches the recent media IDs from the YouTube API for a given source.

  Returns {:ok, [binary()]} | {:error, binary()}
  """
  @impl YoutubeBehaviour
  def get_recent_media_ids(%Source{} = source) do
    api_response =
      source
      |> determine_playlist_id()
      |> do_api_request()

    case api_response do
      {:ok, parsed_json} -> get_media_ids_from_response(parsed_json)
      {:error, reason} -> {:error, reason}
    end
  end

  # The UC prefix is for channels which won't work with this API endpoint. Swapping
  # the prefix to UU will get us the playlist that represents the channel's uploads
  defp determine_playlist_id(%{collection_id: c_id}) do
    String.replace_prefix(c_id, "UC", "UU")
  end

  defp do_api_request(playlist_id) do
    Logger.debug("Fetching recent media IDs from YouTube API for playlist: #{playlist_id}")

    api_base = "https://youtube.googleapis.com/youtube/v3/playlistItems"
    request_url = "#{api_base}?part=contentDetails&maxResults=50&playlistId=#{playlist_id}&key=#{api_key()}"

    case http_client().get(request_url, accept: "application/json") do
      {:ok, response} ->
        Phoenix.json_library().decode(response)

      {:error, reason} ->
        Logger.error("Failed to fetch YouTube API: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp get_media_ids_from_response(parsed_json) do
    parsed_json
    |> Map.get("items", [])
    |> Enum.map(fn item ->
      item
      |> Map.get("contentDetails", %{})
      |> Map.get("videoId", nil)
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
    |> FunctionUtils.wrap_ok()
  end

  defp api_key do
    Settings.get!(:youtube_api_key)
  end

  defp http_client do
    Application.get_env(:pinchflat, :http_client, Pinchflat.HTTP.HTTPClient)
  end
end
