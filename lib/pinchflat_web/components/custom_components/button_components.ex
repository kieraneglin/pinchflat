defmodule PinchflatWeb.CustomComponents.ButtonComponents do
  @moduledoc false
  use Phoenix.Component

  @doc """
  Render a button

  ## Examples

      <.button color="bg-primary" rounding="rounded-sm">
        <span>Click me</span>
      </.button>
  """
  attr :color, :string, default: "bg-primary"
  attr :rounding, :string, default: "rounded-sm"
  attr :class, :string, default: ""

  slot :inner_block, required: true

  def button(assigns) do
    ~H"""
    <button class={[
      "text-center font-medium text-white",
      "#{@rounding} inline-flex items-center justify-center px-10 py-4",
      "#{@color}",
      "hover:bg-opacity-90 lg:px-8 xl:px-10",
      @class
    ]}>
      <%= render_slot(@inner_block) %>
    </button>
    """
  end
end
