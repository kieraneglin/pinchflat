defmodule Pinchflat.PendingTableLive do
  use PinchflatWeb, :live_view
  import Ecto.Query, warn: false

  alias Pinchflat.Repo
  alias Pinchflat.Sources
  alias Pinchflat.Media.MediaQuery
  alias Pinchflat.Utils.NumberUtils

  @limit 10

  def render(%{records: []} = assigns) do
    ~H"""
    <p class="text-black dark:text-white">Nothing Here!</p>
    """
  end

  def render(assigns) do
    ~H"""
    <div>
      <span class="mb-4 inline-block">
        Showing <%= length(@records) %> of <%= @total_record_count %>
      </span>
      <.table rows={@records} table_class="text-black dark:text-white">
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
        <.pagination_controls page_number={@page} total_pages={@total_pages} />
      </section>
    </div>
    """
  end

  def mount(_params, session, socket) do
    page = 1
    source = Sources.get_source!(session["source_id"])
    base_query = generate_base_query(source)
    pagination_attrs = fetch_pagination_attributes(base_query, page)

    {:ok, assign(socket, Map.merge(pagination_attrs, %{base_query: base_query, source: source}))}
  end

  def handle_event("page_change", %{"direction" => direction}, %{assigns: assigns} = socket) do
    direction = if direction == "inc", do: 1, else: -1
    new_page = assigns.page + direction
    new_assigns = fetch_pagination_attributes(assigns.base_query, new_page)

    {:noreply, assign(socket, new_assigns)}
  end

  defp fetch_pagination_attributes(base_query, page) do
    total_record_count = Repo.aggregate(base_query, :count, :id)
    total_pages = ceil(total_record_count / @limit)
    page = NumberUtils.clamp(page, 1, total_pages)
    records = fetch_records(base_query, page)

    %{page: page, total_pages: total_pages, records: records, total_record_count: total_record_count}
  end

  defp generate_base_query(source) do
    MediaQuery.new()
    |> MediaQuery.for_source(source)
    |> MediaQuery.where_pending_download()
    |> order_by(desc: :id)
  end

  defp fetch_records(base_query, page) do
    offset = (page - 1) * @limit

    base_query
    |> limit(^@limit)
    |> offset(^offset)
    |> Repo.all()
  end
end
