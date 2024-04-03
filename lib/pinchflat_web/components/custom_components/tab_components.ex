defmodule PinchflatWeb.CustomComponents.TabComponents do
  @moduledoc false
  use Phoenix.Component

  @doc """
  Takes a list of tabs and renders them in a tabbed layout.
  """
  slot :tab, required: true do
    attr :title, :string, required: true
  end

  slot :tab_append, required: false

  def tabbed_layout(assigns) do
    ~H"""
    <div
      x-data="{ openTab: getTabIndex(0), activeClasses: 'text-meta-5 border-meta-5', inactiveClasses: 'border-transparent' }"
      @hashchange.window="openTab = getTabIndex(openTab)"
      class="w-full"
    >
      <header class="flex flex-col md:flex-row md:justify-between border-b border-strokedark">
        <div class="flex flex-wrap gap-5 sm:gap-10">
          <a
            :for={{tab, idx} <- Enum.with_index(@tab)}
            href="#"
            @click.prevent={"openTab = setTabIndex(#{idx})"}
            x-bind:class={"openTab === #{idx} ? activeClasses : inactiveClasses"}
            class="border-b-2 py-4 w-full sm:w-fit text-sm font-medium hover:text-meta-5 md:text-base"
          >
            <span class="text-xl"><%= tab.title %></span>
          </a>
        </div>
        <div class="mx-4 my-4 lg:my-0 flex gap-5 sm:gap-10 items-center">
          <%= render_slot(@tab_append) %>
        </div>
      </header>
      <div class="mt-4">
        <div :for={{tab, idx} <- Enum.with_index(@tab)} x-show={"openTab === #{idx}"} class="font-medium leading-relaxed">
          <%= render_slot(tab) %>
        </div>
      </div>
    </div>
    """
  end
end
