defmodule PinchflatWeb.Router do
  use PinchflatWeb, :router

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

    resources "/sources", Sources.SourceController do
      resources "/media", MediaItems.MediaItemController, only: [:show, :delete]
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

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:pinchflat, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: PinchflatWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
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
