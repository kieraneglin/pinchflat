defmodule PinchflatWeb.CustomComponents.ButtonComponents do
  @moduledoc false
  use Phoenix.Component, global_prefixes: ~w(x-)

  alias PinchflatWeb.CoreComponents

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
  attr :type, :string, default: "submit"
  attr :disabled, :boolean, default: false
  attr :rest, :global

  slot :inner_block, required: true

  def button(assigns) do
    ~H"""
    <button
      class={[
        "text-center font-medium text-white",
        "#{@rounding} inline-flex items-center justify-center px-8 py-4",
        "#{@color}",
        "hover:bg-opacity-90 lg:px-8 xl:px-10",
        "disabled:bg-opacity-50 disabled:cursor-not-allowed disabled:text-grey-5",
        @class
      ]}
      type={@type}
      disabled={@disabled}
      {@rest}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end

  @doc """
  Render a dropdown based off a button

  ## Examples

      <.button_dropdown text="Actions">
        <:option>TEST</:option>
      </.button_dropdown>
  """
  attr :text, :string, required: true
  attr :class, :string, default: ""

  slot :option, required: true

  def button_dropdown(assigns) do
    ~H"""
    <div x-data="{ dropdownOpen: false }" class={["relative flex", @class]}>
      <span
        x-on:click.prevent="dropdownOpen = !dropdownOpen"
        class={[
          "cursor-pointer inline-flex gap-2.5 rounded-md bg-primary px-5.5 py-3",
          "font-medium text-white hover:bg-opacity-95"
        ]}
      >
        {@text}
        <CoreComponents.icon
          name="hero-chevron-down"
          class="fill-current duration-200 ease-linear mt-1"
          x-bind:class="dropdownOpen && 'rotate-180'"
        />
      </span>
      <div
        x-show="dropdownOpen"
        x-on:click.outside="dropdownOpen = false"
        class="absolute left-0 top-full z-40 mt-2 w-full rounded-md bg-black py-3 shadow-card"
      >
        <ul class="flex flex-col">
          <li :for={option <- @option}>
            <span class="flex px-5 py-2 font-medium text-bodydark2 hover:text-white cursor-pointer">
              {render_slot(option)}
            </span>
          </li>
        </ul>
      </div>
    </div>
    """
  end

  @doc """
  Render a button with an icon. Optionally include a tooltip.

  ## Examples

      <.icon_button icon_name="hero-check" tooltip="Complete" />
  """
  attr :icon_name, :string, required: true
  attr :class, :string, default: ""
  attr :tooltip, :string, default: nil
  attr :rest, :global

  def icon_button(assigns) do
    ~H"""
    <div class="group relative inline-block">
      <button
        class={[
          "flex justify-center items-center rounded-lg ",
          "bg-form-input border-2 border-strokedark",
          "hover:bg-meta-4 hover:border-form-strokedark",
          @class
        ]}
        type="button"
        {@rest}
      >
        <CoreComponents.icon name={@icon_name} class="text-stroke" />
      </button>
      <div
        :if={@tooltip}
        class={[
          "hidden absolute left-1/2 top-full z-20 mt-3 -translate-x-1/2 whitespace-nowrap rounded-md",
          "px-4.5 py-1.5 text-sm font-medium opacity-0 drop-shadow-4 group-hover:opacity-100 group-hover:block bg-meta-4"
        ]}
      >
        <span class="border-light absolute -top-1 left-1/2 -z-10 h-2 w-2 -translate-x-1/2 rotate-45 rounded-sm bg-meta-4">
        </span>
        <span>{@tooltip}</span>
      </div>
    </div>
    """
  end
end
