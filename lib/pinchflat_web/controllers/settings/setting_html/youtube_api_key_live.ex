defmodule Pinchflat.Settings.YoutubeApiKeyLive do
  use PinchflatWeb, :live_view

  alias PinchflatWeb.Settings.SettingHTML

  def render(assigns) do
    ~H"""
    <.input
      type="text"
      id="setting_youtube_api_key"
      name="setting[youtube_api_key]"
      value={@value}
      label="YouTube API Key(s)"
      help={SettingHTML.youtube_api_help()}
      html_help={true}
      inputclass="font-mono text-sm mr-4"
      placeholder="ABC123,DEF456"
      phx-change="youtube_api_key_changed"
    >
      <:input_append>
        <.icon_button icon_name={@icon_name} class="h-12 w-12" phx-click="test_youtube_api_key" tooltip={@tooltip} />
      </:input_append>
    </.input>
    """
  end

  def mount(_params, session, socket) do
    new_assigns = %{
      value: session["value"],
      icon_name: "hero-play",
      tooltip: "Test API Key"
    }

    {:ok, assign(socket, new_assigns)}
  end

  def handle_event("test_youtube_api_key", _params, %{assigns: assigns} = socket) do
    case test_api_key(assigns.value) do
      :ok ->
        Process.send_after(self(), :reset_button_icon, 4_000)
        {:noreply, assign(socket, %{icon_name: "hero-check", tooltip: "Success!"})}

      {:error, reason} ->
        Process.send_after(self(), :reset_button_icon, 4_000)
        {:noreply, assign(socket, %{icon_name: "hero-x-mark", tooltip: reason})}
    end
  end

  def handle_event("youtube_api_key_changed", %{"setting" => setting}, socket) do
    {:noreply, assign(socket, %{value: setting["youtube_api_key"]})}
  end

  def handle_info(:reset_button_icon, socket) do
    {:noreply, assign(socket, %{icon_name: "hero-play", tooltip: "Test API Key"})}
  end

  defp test_api_key(nil), do: {:error, "No API key provided"}
  defp test_api_key(""), do: {:error, "No API key provided"}

  defp test_api_key(keys_string) do
    # Test the first API key provided
    first_key =
      keys_string
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
      |> List.first()

    case first_key do
      nil ->
        {:error, "No API key provided"}

      key ->
        youtube_api().test_api_key(key)
    end
  end

  defp youtube_api do
    Application.get_env(:pinchflat, :youtube_api, Pinchflat.FastIndexing.YoutubeApi)
  end
end
