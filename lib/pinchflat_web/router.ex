defmodule PinchflatWeb.Router do
  use PinchflatWeb, :router
  import Phoenix.LiveDashboard.Router

  # IMPORTANT: `strip_trailing_extension` in endpoint.ex removes
  # the extension from the path
  pipeline :browser do
    plug :basic_auth
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {PinchflatWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :allow_iframe_embed
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :feeds do
    plug :maybe_basic_auth
  end

  scope "/", PinchflatWeb do
    pipe_through :browser

    get "/", Pages.PageController, :home

    resources "/media_profiles", MediaProfiles.MediaProfileController
    resources "/search", Searches.SearchController, only: [:show], singleton: true
    resources "/settings", Settings.SettingController, only: [:show, :update], singleton: true

    resources "/sources", Sources.SourceController do
      post "/force_download", Sources.SourceController, :force_download
      post "/force_index", Sources.SourceController, :force_index

      resources "/media", MediaItems.MediaItemController, only: [:show, :edit, :update, :delete] do
        post "/force_download", MediaItems.MediaItemController, :force_download
      end
    end
  end

  # Routes in here _may not be_ protected by basic auth. This is necessary for
  # media streaming to work for RSS podcast feeds.
  scope "/", PinchflatWeb do
    pipe_through :feeds

    get "/sources/:uuid/feed", Podcasts.PodcastController, :rss_feed
    get "/sources/:uuid/feed_image", Podcasts.PodcastController, :feed_image

    get "/media/:uuid/stream", MediaItems.MediaItemController, :stream
  end

  # No auth or CSRF protection for the health check endpoint
  scope "/", PinchflatWeb do
    pipe_through :api

    get "/healthcheck", HealthController, :check
  end

  scope "/dev" do
    pipe_through :browser

    live_dashboard "/dashboard",
      metrics: PinchflatWeb.Telemetry,
      ecto_repos: [Pinchflat.Repo]
  end

  defp maybe_basic_auth(conn, opts) do
    if Application.get_env(:pinchflat, :expose_feed_endpoints) do
      conn
    else
      basic_auth(conn, opts)
    end
  end

  defp basic_auth(conn, _opts) do
    username = Application.get_env(:pinchflat, :basic_auth_username)
    password = Application.get_env(:pinchflat, :basic_auth_password)

    if credential_set?(username) && credential_set?(password) do
      Plug.BasicAuth.basic_auth(conn, username: username, password: password, realm: "Pinchflat")
    else
      conn
    end
  end

  defp credential_set?(credential) do
    credential && credential != ""
  end

  defp allow_iframe_embed(conn, _opts) do
    delete_resp_header(conn, "x-frame-options")
  end
end
