defmodule PinchflatWeb.Pages.PageController do
  use PinchflatWeb, :controller

  alias Pinchflat.Profiles
  alias Pinchflat.MediaSource

  def home(conn, _params) do
    media_profiles_exist = Profiles.media_profiles_exist?()
    sources_exist = MediaSource.sources_exist?()

    if media_profiles_exist && sources_exist do
      conn
      |> put_session(:onboarding, false)
      |> render(:home)
    else
      conn
      |> put_session(:onboarding, true)
      |> render(:onboarding_checklist,
        media_profiles_exist: media_profiles_exist,
        sources_exist: sources_exist,
        layout: {Layouts, :onboarding}
      )
    end
  end
end
