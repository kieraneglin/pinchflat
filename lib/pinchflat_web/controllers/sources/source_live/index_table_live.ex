defmodule PinchflatWeb.Sources.SourceLive.IndexTableLive do
  use PinchflatWeb, :live_view
  use Pinchflat.Media.MediaQuery
  use Pinchflat.Sources.SourcesQuery

  import PinchflatWeb.Helpers.SortingHelpers

  alias Pinchflat.Repo
  alias Pinchflat.Sources
  alias Pinchflat.Sources.Source
  alias Pinchflat.Media.MediaItem

  def mount(_params, session, socket) do
    initial_params = %{
      sort_key: session["initial_sort_key"],
      sort_direction: session["initial_sort_direction"]
    }

    socket
    |> assign(initial_params)
    |> set_sources()
    |> then(&{:ok, &1})
  end

  # def handle_event("formless-input", %{"event" => "toggle_enabled"} = params, socket) do
  #   source = Sources.get_source!(params["id"])
  #   should_enable = params["value"] == "true"

  #   {:ok, _} = Sources.update_source(source, %{enabled: should_enable})

  #   {:noreply, assign(socket, %{sources: get_sources(socket.assigns)})}
  # end

  def handle_event("sort_update", %{"sort_key" => sort_key}, %{assigns: assigns} = socket) do
    new_sort_key = String.to_existing_atom(sort_key)

    new_params = %{
      sort_key: new_sort_key,
      sort_direction: get_sort_direction(assigns.sort_key, new_sort_key, assigns.sort_direction)
    }

    socket
    |> assign(new_params)
    |> set_sources()
    |> then(&{:noreply, &1})
  end

  defp set_sources(%{assigns: assigns} = socket) do
    sources =
      sources_query()
      |> order_by(^[{assigns.sort_direction, sort_attr(assigns.sort_key)}])
      |> Repo.all()

    assign(socket, %{sources: sources})
  end

  defp sort_attr(:pending_count), do: dynamic([s, mp, dl, pe], field(pe, :pending_count))
  defp sort_attr(:downloaded_count), do: dynamic([s, mp, dl], field(dl, :downloaded_count))
  defp sort_attr(:custom_name), do: dynamic([s], field(s, :custom_name))
  defp sort_attr(_), do: sort_attr(:custom_name)

  defp sources_query do
    downloaded_subquery =
      from(
        m in MediaItem,
        select: %{downloaded_count: count(m.id), source_id: m.source_id},
        where: ^MediaQuery.downloaded(),
        group_by: m.source_id
      )

    pending_subquery =
      from(
        m in MediaItem,
        inner_join: s in assoc(m, :source),
        inner_join: mp in assoc(s, :media_profile),
        select: %{pending_count: count(m.id), source_id: m.source_id},
        where: ^MediaQuery.pending(),
        group_by: m.source_id
      )

    from s in Source,
      as: :source,
      inner_join: mp in assoc(s, :media_profile),
      left_join: d in subquery(downloaded_subquery), on: d.source_id == s.id,
      left_join: p in subquery(pending_subquery), on: p.source_id == s.id,
      on: d.source_id == s.id,
      where: is_nil(s.marked_for_deletion_at) and is_nil(mp.marked_for_deletion_at),
      preload: [media_profile: mp],
      select: map(s, ^Source.__schema__(:fields)),
      select_merge: %{
        downloaded_count: coalesce(d.downloaded_count, 0),
        pending_count: coalesce(p.pending_count, 0)
      }
  end
end
