defmodule PinchflatWeb.Layouts do
  use PinchflatWeb, :html

  embed_templates "layouts/*"
  embed_templates "layouts/partials/*"

  attr :icon, :string, required: true
  attr :text, :string, required: true
  attr :navigate, :any, required: true

  def sidebar_item(assigns) do
    # I'm testing out grouping classes here. Tentative order: font, layout, color, animation, state-modifiers
    ~H"""
    <li>
      <.link
        navigate={@navigate}
        class={[
          "font-medium text-bodydark1",
          "group relative flex items-center gap-2.5 rounded-sm px-4 py-2 duration-300 ease-in-out",
          "duration-300 ease-in-out",
          "hover:bg-graydark dark:hover:bg-meta-4"
        ]}
      >
        <.icon name={@icon} /> <%= @text %>
      </.link>
    </li>
    """
  end
end
