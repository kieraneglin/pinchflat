defmodule PinchflatWeb.Sources.IndexTableLive do
  use PinchflatWeb, :live_view
  use Pinchflat.Media.MediaQuery
  use Pinchflat.Sources.SourcesQuery

  alias Pinchflat.Repo
  alias Pinchflat.Sources
  alias Pinchflat.Sources.Source
  alias Pinchflat.Media.MediaItem

  # TODO: test (and maybe remove existing index tests)
  # TODO: see comments in media profile index view
  def render(assigns) do
    ~H"""
    <.table rows={@sources} table_class="text-white">
      <:col :let={source} label="Name">
        <.subtle_link href={~p"/sources/#{source.id}"}>
          <%= StringUtils.truncate(source.custom_name || source.collection_name, 35) %>
        </.subtle_link>
      </:col>
      <:col :let={source} label="Pending"><.localized_number number={source.pending_count} /></:col>
      <:col :let={source} label="Downloaded"><.localized_number number={source.downloaded_count} /></:col>
      <:col :let={source} label="Retention">
        <%= if source.retention_period_days && source.retention_period_days > 0 do %>
          <.localized_number number={source.retention_period_days} />
          <.pluralize count={source.retention_period_days} word="day" />
        <% else %>
          <span class="text-lg">∞</span>
        <% end %>
      </:col>
      <:col :let={source} label="Media Profile">
        <.subtle_link href={~p"/media_profiles/#{source.media_profile_id}"}>
          <%= source.media_profile.name %>
        </.subtle_link>
      </:col>
      <:col :let={source} label="Enabled?">
        <.input
          name={"source[#{source.id}][enabled]"}
          value={source.enabled}
          id={"source_#{source.id}_enabled"}
          phx-hook="formless-input"
          data-subscribe="change"
          data-event-name="toggle_enabled"
          data-identifier={source.id}
          type="toggle"
        />
      </:col>
      <:col :let={source} label="" class="flex place-content-evenly">
        <.icon_link href={~p"/sources/#{source.id}/edit"} icon="hero-pencil-square" class="mx-1" />
      </:col>
    </.table>
    """
  end

  def mount(_params, _session, socket) do
    {:ok, assign(socket, %{sources: get_sources()})}
  end

  def handle_event("formless-input", %{"event" => "toggle_enabled"} = params, socket) do
    source = Sources.get_source!(params["id"])
    should_enable = params["value"] == "true"

    {:ok, new_source} = Sources.update_source(source, %{enabled: should_enable})
    # Trying to be efficient with the update. Let's see if it pays off
    updated_sources = Enum.map(socket.assigns.sources, fn s -> if s.id == new_source.id, do: new_source, else: s end)

    {:noreply, assign(socket, sources: updated_sources)}
  end

  defp get_sources do
    source_query =
      from s in Source,
        as: :source,
        inner_join: mp in assoc(s, :media_profile),
        where: is_nil(s.marked_for_deletion_at) and is_nil(mp.marked_for_deletion_at),
        preload: [media_profile: mp],
        order_by: [asc: s.custom_name],
        select: map(s, ^Source.__schema__(:fields)),
        select_merge: %{
          downloaded_count:
            subquery(
              from m in MediaItem,
                where: m.source_id == parent_as(:source).id,
                where: ^MediaQuery.downloaded(),
                select: count(m.id)
            ),
          pending_count:
            subquery(
              from m in MediaItem,
                join: s in assoc(m, :source),
                where: m.source_id == parent_as(:source).id,
                where: ^MediaQuery.pending(),
                select: count(m.id)
            )
        }

    Repo.all(source_query)
  end
end
