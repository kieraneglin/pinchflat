defmodule Pinchflat.Sources.MediaItemTableLive do
  use PinchflatWeb, :live_view
  use Pinchflat.Media.MediaQuery

  alias Pinchflat.Repo
  alias Pinchflat.Sources
  alias Pinchflat.Utils.NumberUtils

  @limit 10

  def render(%{total_record_count: 0} = assigns) do
    ~H"""
    <div class="mb-4 flex items-center">
      <.icon_button icon_name="hero-arrow-path" class="h-10 w-10" phx-click="reload_page" />
      <p class="ml-2">Nothing Here!</p>
    </div>
    """
  end

  # TODO: make search results clickable for main search

  def render(assigns) do
    ~H"""
    <div>
      <header class="flex justify-between items-center">
        <span class="mb-4 flex items-center">
          <.icon_button icon_name="hero-arrow-path" class="h-10 w-10" phx-click="reload_page" tooltip="Refresh" />
          <span class="ml-2">Showing <%= length(@records) %> of <%= @filtered_record_count %> total</span>
        </span>
        <div class="bg-meta-4 rounded-md">
          <div class="relative">
            <span class="absolute left-2 top-1/2 -translate-y-1/2 flex">
              <.icon name="hero-magnifying-glass" />
            </span>
            <form phx-change="search_term" phx-submit="search_term">
              <input
                type="text"
                name="q"
                value={@search_term}
                placeholder="Search in table..."
                class="w-full bg-transparent pl-9 pr-4 border-0 focus:ring-0 focus:outline-none"
                phx-debounce="200"
              />
            </form>
          </div>
        </div>
      </header>
      <.table rows={@records} table_class="text-white">
        <:col :let={media_item} label="Title">
          <.subtle_link href={~p"/sources/#{@source.id}/media/#{media_item.id}"}>
            <%= StringUtils.truncate(media_item.title, 50) %>
          </.subtle_link>
        </:col>
        <:col :let={media_item} :if={@media_state == "other"} label="Manually Ignored?">
          <.icon name={if media_item.prevent_download, do: "hero-check", else: "hero-x-mark"} />
        </:col>
        <:col :let={media_item} label="" class="flex justify-end">
          <.icon_link href={~p"/sources/#{@source.id}/media/#{media_item.id}/edit"} icon="hero-pencil-square" class="mr-4" />
        </:col>
      </.table>
      <section class="flex justify-center mt-5">
        <.live_pagination_controls page_number={@page} total_pages={@total_pages} />
      </section>
    </div>
    """
  end

  def mount(_params, session, socket) do
    PinchflatWeb.Endpoint.subscribe("media_table")

    page = 1
    media_state = session["media_state"]
    source = Sources.get_source!(session["source_id"])
    base_query = generate_base_query(source, media_state)
    pagination_attrs = fetch_pagination_attributes(base_query, page, nil)

    new_assigns =
      Map.merge(
        pagination_attrs,
        %{
          base_query: base_query,
          source: source,
          media_state: media_state
        }
      )

    {:ok, assign(socket, new_assigns)}
  end

  def handle_event("page_change", %{"direction" => direction}, %{assigns: assigns} = socket) do
    direction = if direction == "inc", do: 1, else: -1
    new_page = assigns.page + direction
    new_assigns = fetch_pagination_attributes(assigns.base_query, new_page, assigns.search_term)

    {:noreply, assign(socket, new_assigns)}
  end

  def handle_event("search_term", params, socket) do
    search_term = Map.get(params, "q", nil)
    new_assigns = fetch_pagination_attributes(socket.assigns.base_query, 1, search_term)

    {:noreply, assign(socket, new_assigns)}
  end

  # This, along with the handle_info below, is a pattern to reload _all_
  # tables on page rather than just the one that triggered the reload.
  def handle_event("reload_page", _params, socket) do
    PinchflatWeb.Endpoint.broadcast("media_table", "reload", nil)

    {:noreply, socket}
  end

  def handle_info(%{topic: "media_table", event: "reload"}, %{assigns: assigns} = socket) do
    new_assigns = fetch_pagination_attributes(assigns.base_query, assigns.page, assigns.search_term)

    {:noreply, assign(socket, new_assigns)}
  end

  defp fetch_pagination_attributes(base_query, page, search_term) do
    filtered_base_query = filter_base_query(base_query, search_term)

    total_record_count = Repo.aggregate(base_query, :count, :id)
    filtered_record_count = Repo.aggregate(filtered_base_query, :count, :id)
    total_pages = max(ceil(filtered_record_count / @limit), 1)
    page = NumberUtils.clamp(page, 1, total_pages)
    records = fetch_records(filtered_base_query, page)

    %{
      page: page,
      total_pages: total_pages,
      records: records,
      search_term: search_term,
      total_record_count: total_record_count,
      filtered_record_count: filtered_record_count
    }
  end

  defp fetch_records(base_query, page) do
    offset = (page - 1) * @limit

    base_query
    |> limit(^@limit)
    |> offset(^offset)
    |> Repo.all()
  end

  defp generate_base_query(source, "pending") do
    MediaQuery.new()
    |> MediaQuery.require_assoc(:media_profile)
    |> MediaQuery.require_assoc(:media_items_search_index)
    |> where(^dynamic(^MediaQuery.for_source(source) and ^MediaQuery.pending()))
    |> order_by(desc: fragment("rank"), desc: :id)
  end

  defp generate_base_query(source, "downloaded") do
    MediaQuery.new()
    |> MediaQuery.require_assoc(:media_items_search_index)
    |> where(^dynamic(^MediaQuery.for_source(source) and ^MediaQuery.downloaded()))
    |> order_by(desc: fragment("rank"), desc: :id)
  end

  defp generate_base_query(source, "other") do
    MediaQuery.new()
    |> MediaQuery.require_assoc(:media_profile)
    |> MediaQuery.require_assoc(:media_items_search_index)
    |> where(
      ^dynamic(
        ^MediaQuery.for_source(source) and
          (not (^MediaQuery.downloaded()) and not (^MediaQuery.pending()))
      )
    )
    |> order_by(desc: fragment("rank"), desc: :id)
  end

  defp filter_base_query(base_query, search_term) do
    base_query
    |> where(^MediaQuery.matches_search_term(search_term))
  end
end
