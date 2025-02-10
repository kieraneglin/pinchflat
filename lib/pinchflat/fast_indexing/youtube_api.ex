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

  @agent_name {:global, __MODULE__.KeyIndex}

  @doc """
  Determines if the YouTube API is enabled for fast indexing by checking
  if the user has an API key set

  Returns boolean()
  """
  @impl YoutubeBehaviour
  def enabled?, do: Enum.any?(api_keys())

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

    playlist_id
    |> construct_api_endpoint()
    |> http_client().get(accept: "application/json")
    |> case do
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

  defp api_keys do
    case Settings.get!(:youtube_api_key) do
      nil ->
        []

      keys ->
        keys
        |> String.split(",")
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))
    end
  end

  defp get_or_start_api_key_agent do
    case Agent.start(fn -> 0 end, name: @agent_name) do
      {:ok, pid} -> pid
      {:error, {:already_started, pid}} -> pid
    end
  end

  # Gets the next API key in round-robin fashion
  defp next_api_key do
    keys = api_keys()

    case keys do
      [] ->
        nil

      keys ->
        pid = get_or_start_api_key_agent()

        current_index =
          Agent.get_and_update(pid, fn current ->
            {current, rem(current + 1, length(keys))}
          end)

        Logger.debug("Using YouTube API key: #{Enum.at(keys, current_index)}")
        Enum.at(keys, current_index)
    end
  end

  defp construct_api_endpoint(playlist_id) do
    api_base = "https://youtube.googleapis.com/youtube/v3/playlistItems"
    property_type = "contentDetails"
    max_results = 50

    "#{api_base}?part=#{property_type}&maxResults=#{max_results}&playlistId=#{playlist_id}&key=#{next_api_key()}"
  end

  defp http_client do
    Application.get_env(:pinchflat, :http_client, Pinchflat.HTTP.HTTPClient)
  end
end
