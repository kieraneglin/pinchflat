defmodule PinchflatWeb.CustomComponents.TextComponents do
  @moduledoc false
  use Phoenix.Component

  alias Pinchflat.Utils.NumberUtils
  alias PinchflatWeb.CoreComponents

  @doc """
  Renders a code block with the given content.
  """
  slot :inner_block

  def inline_code(assigns) do
    ~H"""
    <code class="inline-block text-sm font-mono text-gray bg-boxdark rounded-md p-0.5 mx-0.5 text-nowrap">
      {render_slot(@inner_block)}
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
      {render_slot(@inner_block)}
    </.link>
    """
  end

  @doc """
  Renders a subtle link with the given href and content.
  """
  attr :href, :string, required: true
  attr :target, :string, default: "_self"
  slot :inner_block

  def subtle_link(assigns) do
    ~H"""
    <.link href={@href} target={@target} class="underline decoration-bodydark decoration-1 hover:decoration-white">
      {render_slot(@inner_block)}
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

  @doc """
  Renders a block of text with each line broken into a separate span and links highlighted.
  """
  attr :text, :string, required: true

  def render_description(assigns) do
    formatted_text =
      Regex.split(~r{https?://\S+}, assigns.text, include_captures: true)
      |> Enum.map(fn
        "http" <> _ = url ->
          Phoenix.HTML.Tag.content_tag(:a, url, class: "text-blue-500 hover:text-blue-300", href: url, target: "_blank")

        text ->
          text
          |> String.split("\n", trim: false)
          |> Enum.intersperse(Phoenix.HTML.Tag.tag(:span, class: "inline-block mt-2"))
      end)

    assigns = Map.put(assigns, :text, formatted_text)

    ~H"""
    <span>{@text}</span>
    """
  end

  @doc """
  Renders a UTC datetime in the specified format and timezone
  """
  attr :datetime, :any, required: true
  attr :format, :string, default: "%Y-%m-%d %H:%M:%S"
  attr :timezone, :string, default: nil

  def datetime_in_zone(assigns) do
    timezone = assigns.timezone || Application.get_env(:pinchflat, :timezone)
    assigns = Map.put(assigns, :timezone, timezone)

    ~H"""
    <time>{Calendar.strftime(Timex.Timezone.convert(@datetime, @timezone), @format)}</time>
    """
  end

  @doc """
  Renders a localized number using the Intl.NumberFormat API, falling back to the raw number if needed
  """
  attr :number, :any, required: true

  def localized_number(assigns) do
    ~H"""
    <span x-data x-text={"Intl.NumberFormat().format(#{@number})"}>{@number}</span>
    """
  end

  @doc """
  Renders a word with a suffix if the count is not 1
  """
  attr :word, :string, required: true
  attr :count, :integer, required: true
  attr :suffix, :string, default: "s"

  def pluralize(assigns) do
    ~H"""
    {@word}{if @count == 1, do: "", else: @suffix}
    """
  end

  @doc """
  Renders a human-readable byte size
  """

  attr :byte_size, :integer, required: true

  def readable_filesize(assigns) do
    {num, suffix} = NumberUtils.human_byte_size(assigns.byte_size, precision: 2)

    assigns =
      Map.merge(assigns, %{
        num: num,
        suffix: suffix
      })

    ~H"""
    <.localized_number number={@num} /> {@suffix}
    """
  end

  attr :tooltip, :string, required: true
  attr :position, :string, default: ""
  attr :tooltip_class, :any, default: ""
  attr :tooltip_arrow_class, :any, default: ""
  slot :inner_block

  def tooltip(%{position: "bottom-right"} = assigns) do
    ~H"""
    <.tooltip tooltip={@tooltip} tooltip_class={@tooltip_class} tooltip_arrow_class={["-top-1", @tooltip_arrow_class]}>
      {render_slot(@inner_block)}
    </.tooltip>
    """
  end

  def tooltip(%{position: "bottom"} = assigns) do
    ~H"""
    <.tooltip
      tooltip={@tooltip}
      tooltip_class={["left-1/2 -translate-x-1/2", @tooltip_class]}
      tooltip_arrow_class={["-top-1 left-1/2 -translate-x-1/2", @tooltip_arrow_class]}
    >
      {render_slot(@inner_block)}
    </.tooltip>
    """
  end

  def tooltip(assigns) do
    ~H"""
    <div class="group relative inline-block cursor-pointer">
      <div>
        {render_slot(@inner_block)}
      </div>
      <div
        :if={@tooltip}
        class={[
          "hidden absolute top-full z-20 mt-3 whitespace-nowrap rounded-md",
          "p-1.5 text-sm font-medium opacity-0 drop-shadow-4 group-hover:opacity-100 group-hover:block bg-meta-4",
          "border border-form-strokedark text-wrap",
          @tooltip_class
        ]}
      >
        <span class={[
          "border-t border-l border-form-strokedark absolute -z-10 h-2 w-2 rotate-45 rounded-sm bg-meta-4",
          @tooltip_arrow_class
        ]}>
        </span>
        <div class="px-3">{@tooltip}</div>
      </div>
    </div>
    """
  end
end
