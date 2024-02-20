defmodule PinchflatWeb.CustomComponents.TextComponents do
  @moduledoc false
  use Phoenix.Component

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

  def reference_link(assigns) do
    ~H"""
    <.link href={@href} target="_blank" class="text-blue-500 hover:text-blue-300">
      <%= render_slot(@inner_block) %>
    </.link>
    """
  end
end
