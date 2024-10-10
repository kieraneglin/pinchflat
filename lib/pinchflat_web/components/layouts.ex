defmodule PinchflatWeb.Layouts do
  use PinchflatWeb, :html

  embed_templates "layouts/*"
  embed_templates "layouts/partials/*"

  @doc """
  Renders a sidebar menu item link

  ## Examples

      <.sidebar_link icon="hero-home" text="Home" href="/" />
  """
  attr :icon, :string, required: true
  attr :text, :string, required: true
  attr :href, :any, required: true
  attr :target, :any, default: "_self"

  def sidebar_item(assigns) do
    ~H"""
    <li class="text-bodydark1">
      <.sidebar_link icon={@icon} text={@text} href={@href} target={@target} />
    </li>
    """
  end

  @doc """
  Renders a sidebar menu item with a submenu

  ## Examples

      <.sidebar_submenu icon="hero-home" text="Home" current_path="/">
        <:submenu icon="hero-home" text="Home" href="/" />
      </.sidebar_submenu>
  """

  attr :icon, :string, required: true
  attr :text, :string, required: true
  attr :current_path, :string, required: true

  slot :submenu do
    attr :icon, :string
    attr :text, :string
    attr :href, :any
    attr :target, :any
  end

  def sidebar_submenu(assigns) do
    initially_selected = Enum.any?(assigns[:submenu], &(&1[:href] == assigns[:current_path]))
    assigns = Map.put(assigns, :initially_selected, initially_selected)

    ~H"""
    <li class="text-bodydark1" x-data={"{ selected: #{@initially_selected} }"}>
      <span
        class={[
          "font-medium cursor-pointer",
          "group relative flex items-center justify-between rounded-sm px-4 py-2 duration-300 ease-in-out",
          "duration-300 ease-in-out",
          "hover:bg-meta-4"
        ]}
        x-on:click="selected = !selected"
      >
        <span class="flex items-center gap-2.5">
          <.icon name={@icon} /> <%= @text %>
        </span>
        <span class="text-bodydark2">
          <.icon name="hero-chevron-down" x-bind:class="{ 'rotate-180': selected }" />
        </span>
      </span>

      <ul x-cloak x-show="selected">
        <li :for={menu <- @submenu} class="text-bodydark2">
          <.sidebar_link icon={menu[:icon]} text={menu[:text]} href={menu[:href]} target={menu[:target]} class="pl-10" />
        </li>
      </ul>
    </li>
    """
  end

  @doc """
  Renders a sidebar menu item link

  ## Examples

      <.sidebar_link icon="hero-home" text="Home" href="/" />
  """
  attr :icon, :string
  attr :text, :string, required: true
  attr :href, :any, required: true
  attr :target, :any, default: "_self"
  attr :class, :string, default: ""

  def sidebar_link(assigns) do
    ~H"""
    <.link
      href={@href}
      target={@target}
      class={[
        "font-medium",
        "group relative flex items-center gap-2.5 rounded-sm px-4 py-2 duration-300 ease-in-out",
        "duration-300 ease-in-out",
        "hover:bg-meta-4",
        @class
      ]}
    >
      <.icon :if={@icon} name={@icon} /> <%= @text %>
    </.link>
    """
  end
end
