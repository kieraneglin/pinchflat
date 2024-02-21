defmodule PinchflatWeb.Router do
  use PinchflatWeb, :router

  pipeline :browser do
    plug :basic_auth
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {PinchflatWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
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

  # Other scopes may use custom stacks.
  # scope "/api", PinchflatWeb do
  #   pipe_through :api
  # end

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

  defp basic_auth(conn, _opts) do
    username = Application.get_env(:pinchflat, :basic_auth_username)
    password = Application.get_env(:pinchflat, :basic_auth_password)

    if username && password do
      Plug.BasicAuth.basic_auth(conn, username: username, password: password, realm: "Pinchflat")
    else
      conn
    end
  end
end
