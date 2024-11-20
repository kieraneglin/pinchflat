defmodule PinchflatWeb.MediaProfiles.IndexTableLive do
  use PinchflatWeb, :live_view
  use Pinchflat.Profiles.ProfilesQuery

  alias Pinchflat.Repo

  def render(assigns) do
    ~H"""
    <.table rows={@media_profiles} table_class="text-black dark:text-white">
      <:col :let={media_profile} label="Name">
        <.subtle_link href={~p"/media_profiles/#{media_profile.id}"}>
          <%= media_profile.name %>
        </.subtle_link>
      </:col>
      <:col :let={media_profile} label="Preferred Resolution">
        <%= media_profile.preferred_resolution %>
      </:col>
      <:col :let={media_profile} label="Enabled?">
        <.input
          name={"media_profile[#{media_profile.id}][enabled]"}
          id={"media_profile_#{media_profile.id}_enabled"}
          phx-hook="formless-input"
          data-subscribe="change"
          data-event-name="toggle_enabled"
          data-identifier={media_profile.id}
          type="toggle"
        />
      </:col>
      <:col :let={media_profile} label="" class="flex justify-end">
        <.icon_link href={~p"/media_profiles/#{media_profile.id}/edit"} icon="hero-pencil-square" class="mr-4" />
      </:col>
    </.table>
    """
  end

  def mount(_params, _session, socket) do
    new_assigns = %{
      media_profiles: get_media_profiles()
    }

    {:ok, assign(socket, new_assigns)}
  end

  def handle_event("formless-input", %{"event" => "toggle_enabled"} = params, socket) do
    # should_enable = params["value"] == "true"
    IO.inspect(params)

    {:noreply, socket}
  end

  defp get_media_profiles do
    ProfilesQuery.new()
    |> where([mp], is_nil(mp.marked_for_deletion_at))
    |> order_by(asc: :name)
    |> Repo.all()
  end
end
