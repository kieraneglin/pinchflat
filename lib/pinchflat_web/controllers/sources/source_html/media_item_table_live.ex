defmodule Pinchflat.Sources.MediaItemTableLive do
  use PinchflatWeb, :live_view
  import Ecto.Query, warn: false

  alias Pinchflat.Repo
  alias Pinchflat.Sources
  alias Pinchflat.Media.MediaQuery
  alias Pinchflat.Utils.NumberUtils

  @limit 10

  def render(%{records: []} = assigns) do
    ~H"""
    <div class="mb-4 flex items-center">
      <button
        class="flex justify-center items-center rounded-lg bg-form-input border-2 border-strokedark h-10 w-10"
        phx-click="reload_page"
        type="button"
      >
        <.icon name="hero-arrow-path" class="text-stroke" />
      </button>
      <p class="ml-2">Nothing Here!</p>
    </div>
    """
  end

  def render(assigns) do
    ~H"""
    <div>
      <span class="mb-4 flex items-center">
        <button
          class="flex justify-center items-center rounded-lg bg-form-input border-2 border-strokedark h-10 w-10"
          phx-click="reload_page"
          type="button"
        >
          <.icon name="hero-arrow-path" class="text-stroke" />
        </button>
        <span class="ml-2">Showing <%= length(@records) %> of <%= @total_record_count %></span>
      </span>
      <.table rows={@records} table_class="text-white">
        <:col :let={media_item} label="Title">
          <.subtle_link href={~p"/sources/#{@source.id}/media/#{media_item.id}"}>
            <%= StringUtils.truncate(media_item.title, 50) %>
          </.subtle_link>
        </:col>
        <:col :let={media_item} label="" class="flex place-content-evenly">
          <.icon_link href={~p"/sources/#{@source.id}/media/#{media_item.id}"} icon="hero-eye" class="mx-1" />
          <.icon_link href={~p"/sources/#{@source.id}/media/#{media_item.id}/edit"} icon="hero-pencil-square" class="mx-1" />
        </:col>
      </.table>
      <section class="flex justify-center mt-5">
        <.live_pagination_controls page_number={@page} total_pages={@total_pages} />
      </section>
    </div>
    """
  end

  def mount(_params, session, socket) do
    page = 1
    media_state = session["media_state"]
    source = Sources.get_source!(session["source_id"])
    base_query = generate_base_query(source, media_state)
    pagination_attrs = fetch_pagination_attributes(base_query, page)

    {:ok, assign(socket, Map.merge(pagination_attrs, %{base_query: base_query, source: source}))}
  end

  def handle_event("page_change", %{"direction" => direction}, %{assigns: assigns} = socket) do
    direction = if direction == "inc", do: 1, else: -1
    new_page = assigns.page + direction
    new_assigns = fetch_pagination_attributes(assigns.base_query, new_page)

    {:noreply, assign(socket, new_assigns)}
  end

  def handle_event("reload_page", _params, %{assigns: assigns} = socket) do
    new_assigns = fetch_pagination_attributes(assigns.base_query, assigns.page)

    {:noreply, assign(socket, new_assigns)}
  end

  defp fetch_pagination_attributes(base_query, page) do
    total_record_count = Repo.aggregate(base_query, :count, :id)
    total_pages = max(ceil(total_record_count / @limit), 1)
    page = NumberUtils.clamp(page, 1, total_pages)
    records = fetch_records(base_query, page)

    %{page: page, total_pages: total_pages, records: records, total_record_count: total_record_count}
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
    |> MediaQuery.for_source(source)
    |> MediaQuery.where_pending_download()
    |> order_by(desc: :id)
  end

  defp generate_base_query(source, "downloaded") do
    MediaQuery.new()
    |> MediaQuery.for_source(source)
    |> MediaQuery.with_media_filepath()
    |> order_by(desc: :id)
  end
end
