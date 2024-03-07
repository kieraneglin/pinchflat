defmodule PinchflatWeb.Pages.PageController do
  alias Pinchflat.Media.MediaItem
  use PinchflatWeb, :controller

  alias Pinchflat.Repo
  alias Pinchflat.Sources.Source
  alias Pinchflat.Media.MediaItem
  alias Pinchflat.Profiles.MediaProfile

  def home(conn, params) do
    force_onboarding = params["onboarding"]
    media_profiles_exist = Repo.exists?(MediaProfile)
    sources_exist = Repo.exists?(Source)

    if !force_onboarding && media_profiles_exist && sources_exist do
      render_home_page(conn)
    else
      render_onboarding_page(conn, media_profiles_exist, sources_exist)
    end
  end

  defp render_home_page(conn) do
    Settings.set!(:onboarding, false)
    media_profile_count = Repo.aggregate(MediaProfile, :count, :id)
    source_count = Repo.aggregate(Source, :count, :id)
    media_item_count = Repo.aggregate(MediaItem, :count, :id)

    conn
    |> render(:home,
      media_profile_count: media_profile_count,
      source_count: source_count,
      media_item_count: media_item_count
    )
  end

  defp render_onboarding_page(conn, media_profiles_exist, sources_exist) do
    Settings.set!(:onboarding, true)

    conn
    |> render(:onboarding_checklist,
      media_profiles_exist: media_profiles_exist,
      sources_exist: sources_exist,
      layout: {Layouts, :onboarding}
    )
  end
end
