defmodule PinchflatWeb.Pages.PageController do
  use PinchflatWeb, :controller
  use Pinchflat.Media.MediaQuery

  alias Pinchflat.Repo
  alias Pinchflat.Sources.Source
  alias Pinchflat.Profiles.MediaProfile

  def home(conn, params) do
    done_onboarding = params["onboarding"] == "0"
    force_onboarding = params["onboarding"] == "1"

    if done_onboarding, do: Settings.set(onboarding: false)

    if force_onboarding || Settings.get!(:onboarding) do
      render_onboarding_page(conn)
    else
      render_home_page(conn)
    end
  end

  defp render_home_page(conn) do
    conn
    |> render(:home,
      media_profile_count: Repo.aggregate(MediaProfile, :count, :id),
      source_count: Repo.aggregate(Source, :count, :id),
      media_item_count:
        MediaQuery.new()
        |> MediaQuery.with_media_downloaded_at()
        |> Repo.aggregate(:count, :id)
    )
  end

  defp render_onboarding_page(conn) do
    Settings.set(onboarding: true)

    conn
    |> render(:onboarding_checklist,
      media_profiles_exist: Repo.exists?(MediaProfile),
      sources_exist: Repo.exists?(Source),
      layout: {Layouts, :onboarding}
    )
  end
end
