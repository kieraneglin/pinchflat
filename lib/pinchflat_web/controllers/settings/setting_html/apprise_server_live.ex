defmodule Pinchflat.Settings.AppriseServerLive do
  use PinchflatWeb, :live_view

  alias PinchflatWeb.Settings.SettingHTML

  def render(assigns) do
    ~H"""
    <.input
      type="text"
      id="setting_apprise_server"
      name="setting[apprise_server]"
      value={@value}
      label="Apprise Server"
      help={SettingHTML.apprise_server_help()}
      html_help={true}
      inputclass="font-mono text-sm mr-4"
      placeholder="https://discordapp.com/api/webhooks/{WebhookID}/{WebhookToken}"
      phx-change="apprise_server_changed"
    >
      <:input_append>
        <.icon_button icon_name={@icon_name} class="h-12 w-12" phx-click="send_apprise_test" tooltip={@tooltip} />
      </:input_append>
    </.input>
    """
  end

  def mount(_params, session, socket) do
    new_assigns = %{
      value: session["value"],
      icon_name: "hero-paper-airplane",
      tooltip: "Send Test"
    }

    {:ok, assign(socket, new_assigns)}
  end

  def handle_event("send_apprise_test", _params, %{assigns: assigns} = socket) do
    backend_runner().run([assigns.value], title: "Pinchflat Test", body: "This is a test message from Pinchflat")
    Process.send_after(self(), :reset_button_icon, 4_000)

    {:noreply, assign(socket, %{icon_name: "hero-check", tooltip: "Sent!"})}
  end

  def handle_event("apprise_server_changed", %{"setting" => setting}, socket) do
    {:noreply, assign(socket, %{value: setting["apprise_server"]})}
  end

  def handle_info(:reset_button_icon, socket) do
    {:noreply, assign(socket, %{icon_name: "hero-paper-airplane", tooltip: "Send Test"})}
  end

  defp backend_runner do
    Application.get_env(:pinchflat, :apprise_runner)
  end
end
