defmodule Pinchflat.Pages.HistoryTableLive do
  use PinchflatWeb, :live_view
  import Ecto.Query, warn: false

  alias Pinchflat.Repo
  alias Pinchflat.Media.MediaQuery
  alias Pinchflat.Utils.NumberUtils
  alias PinchflatWeb.CustomComponents.TextComponents

  @limit 10

  def render(%{records: []} = assigns) do
    ~H"""
    <div class="mb-4 flex items-center">
      <.icon_button icon_name="hero-arrow-path" class="h-10 w-10" phx-click="reload_page" />
      <p class="ml-2">Nothing Here!</p>
    </div>
    """
  end

  def render(assigns) do
    ~H"""
    <div>
      <span class="mb-4 flex items-center">
        <.icon_button icon_name="hero-arrow-path" class="h-10 w-10" phx-click="reload_page" tooltip="Refresh" />
        <span class="ml-2">Showing <%= length(@records) %> of <%= @total_record_count %></span>
      </span>
      <div class="max-w-full overflow-x-auto">
        <.table rows={@records} table_class="text-white">
          <:col :let={media_item} label="Title">
            <.subtle_link href={~p"/sources/#{media_item.source_id}/media/#{media_item}"}>
              <%= StringUtils.truncate(media_item.title, 35) %>
            </.subtle_link>
          </:col>
          <:col :let={media_item} label="Upload Date">
            <%= media_item.upload_date %>
          </:col>
          <:col :let={media_item} label="Indexed At">
            <%= format_datetime(media_item.inserted_at) %>
          </:col>
          <:col :let={media_item} label="Downloaded At">
            <%= format_datetime(media_item.media_downloaded_at) %>
          </:col>
          <:col :let={media_item} label="Source">
            <.subtle_link href={~p"/sources/#{media_item.source_id}"}>
              <%= StringUtils.truncate(media_item.source.custom_name, 35) %>
            </.subtle_link>
          </:col>
        </.table>
      </div>
      <section class="flex justify-center mt-5">
        <.live_pagination_controls page_number={@page} total_pages={@total_pages} />
      </section>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    page = 1
    base_query = generate_base_query()
    pagination_attrs = fetch_pagination_attributes(base_query, page)

    {:ok, assign(socket, Map.merge(pagination_attrs, %{base_query: base_query}))}
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
    |> Repo.preload(:source)
  end

  defp generate_base_query do
    MediaQuery.new()
    |> MediaQuery.where_pending_or_downloaded()
    |> order_by(desc: :id)
  end

  defp format_datetime(nil), do: ""

  defp format_datetime(datetime) do
    TextComponents.datetime_in_zone(%{datetime: datetime, format: "%Y-%m-%d %H:%M"})
  end
end
