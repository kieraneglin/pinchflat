defmodule Pinchflat.UpgradeButtonLive do
  use PinchflatWeb, :live_view

  def render(assigns) do
    ~H"""
    <form phx-change="check_matching_text">
      <.input type="text" name="unlock-pro-textbox" value="" />
    </form>

    <.button
      class="w-full mt-4"
      type="button"
      disabled={@button_disabled}
      phx-click={hide_modal("upgrade-modal")}
      x-on:click="setTimeout(() => { proEnabled = true }, 200)"
    >
      Unlock Pro
    </.button>
    """
  end

  def mount(_params, _session, socket) do
    {:ok, assign(socket, :button_disabled, true)}
  end

  def handle_event("check_matching_text", %{"unlock-pro-textbox" => text}, socket) do
    normalized_text =
      text
      |> String.trim()
      |> String.downcase()

    if normalized_text == "got it!" do
      Settings.set!(:pro_enabled, true)

      {:noreply, update(socket, :button_disabled, fn _ -> false end)}
    else
      {:noreply, update(socket, :button_disabled, fn _ -> true end)}
    end
  end
end
