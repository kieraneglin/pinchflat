defmodule PinchflatWeb.CustomComponents.TabComponents do
  @moduledoc false
  use Phoenix.Component

  @doc """
  Takes a list of tabs and renders them in a tabbed layout.
  """
  slot :tab, required: true do
    attr :title, :string, required: true
  end

  def tabbed_layout(assigns) do
    ~H"""
    <div
      x-data="{ openTab: 0, activeClasses: 'text-meta-5 border-meta-5', inactiveClasses: 'border-transparent' }"
      class="w-full"
    >
      <div class="mb-6 flex flex-wrap gap-5 border-b border-strokedark sm:gap-10">
        <a
          :for={{tab, idx} <- Enum.with_index(@tab)}
          href="#"
          @click.prevent={"openTab = #{idx}"}
          x-bind:class={"openTab === #{idx} ? activeClasses : inactiveClasses"}
          class="border-b-2 py-4 text-sm font-medium hover:text-meta-5 md:text-base"
        >
          <span class="text-xl"><%= tab.title %></span>
        </a>
      </div>
      <div>
        <div :for={{tab, idx} <- Enum.with_index(@tab)} x-show={"openTab === #{idx}"} class="font-medium leading-relaxed">
          <%= render_slot(tab) %>
        </div>
      </div>
    </div>
    """
  end
end
