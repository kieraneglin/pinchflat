defmodule PinchflatWeb.Sources.SourceLive.SourceEnableToggle do
  use PinchflatWeb, :live_component

  alias Pinchflat.Sources
  alias Pinchflat.Sources.Source

  def render(assigns) do
    ~H"""
    <div>
      <.form :let={f} for={@form} phx-change="update" phx-target={@myself} class="enabled_toggle_form">
        <.input id={"source_#{@source_id}_enabled_input"} field={f[:enabled]} type="toggle" />
      </.form>
    </div>
    """
  end

  def update(assigns, socket) do
    initial_data = %{
      source_id: assigns.source.id,
      form: Sources.change_source(%Source{}, assigns.source)
    }

    socket
    |> assign(initial_data)
    |> then(&{:ok, &1})
  end

  def handle_event("update", %{"source" => source_params}, %{assigns: assigns} = socket) do
    assigns.source_id
    |> Sources.get_source!()
    |> Sources.update_source(source_params)

    {:noreply, socket}
  end
end
