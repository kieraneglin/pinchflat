defmodule PinchflatWeb.Plugs do
  use PinchflatWeb, :router

  # TODO: doc and test
  def maybe_basic_auth(conn, opts) do
    if Application.get_env(:pinchflat, :expose_feed_endpoints) do
      conn
    else
      basic_auth(conn, opts)
    end
  end

  def basic_auth(conn, _opts) do
    username = Application.get_env(:pinchflat, :basic_auth_username)
    password = Application.get_env(:pinchflat, :basic_auth_password)

    if credential_set?(username) && credential_set?(password) do
      Plug.BasicAuth.basic_auth(conn, username: username, password: password, realm: "Pinchflat")
    else
      conn
    end
  end

  def allow_iframe_embed(conn, _opts) do
    delete_resp_header(conn, "x-frame-options")
  end

  def token_protected_route(%{query_params: %{"route_token" => route_token}} = conn, _opts) do
    # TODO: make this match against the token in the database
    conn
  end

  def token_protected_route(conn, _opts) do
    conn
    |> send_resp(:unauthorized, "Unauthorized")
    |> halt()
  end

  defp credential_set?(credential) do
    credential && credential != ""
  end
end
