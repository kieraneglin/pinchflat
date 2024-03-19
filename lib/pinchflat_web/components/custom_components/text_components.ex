defmodule PinchflatWeb.CustomComponents.TextComponents do
  @moduledoc false
  use Phoenix.Component

  alias PinchflatWeb.CoreComponents

  @doc """
  Renders a code block with the given content.
  """
  slot :inner_block

  def inline_code(assigns) do
    ~H"""
    <code class="inline-block text-sm font-mono text-gray bg-boxdark rounded-md p-0.5 mx-0.5 text-nowrap">
      <%= render_slot(@inner_block) %>
    </code>
    """
  end

  @doc """
  Renders a reference link with the given href and content.
  """
  attr :href, :string, required: true
  slot :inner_block

  def inline_link(assigns) do
    ~H"""
    <.link href={@href} target="_blank" class="text-blue-500 hover:text-blue-300">
      <%= render_slot(@inner_block) %>
    </.link>
    """
  end

  @doc """
  Renders a subtle link with the given href and content.
  """
  attr :href, :string, required: true
  slot :inner_block

  def subtle_link(assigns) do
    ~H"""
    <.link href={@href} class="underline decoration-bodydark decoration-1 hover:decoration-white">
      <%= render_slot(@inner_block) %>
    </.link>
    """
  end

  @doc """
  Renders an icon as a link with the given href.
  """
  attr :href, :string, required: true
  attr :icon, :string, required: true
  attr :class, :string, default: ""

  def icon_link(assigns) do
    ~H"""
    <.link href={@href} class={["hover:text-secondary duration-200 ease-in-out", @class]}>
      <CoreComponents.icon name={@icon} />
    </.link>
    """
  end
end
