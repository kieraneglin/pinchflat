defmodule PinchflatWeb.PlugsTest do
  use PinchflatWeb.ConnCase

  alias PinchflatWeb.Plugs
  alias Pinchflat.Settings

  describe "maybe_basic_auth/2" do
    setup do
      old_username = Application.get_env(:pinchflat, :basic_auth_username)
      old_password = Application.get_env(:pinchflat, :basic_auth_password)
      old_expose_feed_endpoints = Application.get_env(:pinchflat, :expose_feed_endpoints)

      on_exit(fn ->
        Application.put_env(:pinchflat, :basic_auth_username, old_username)
        Application.put_env(:pinchflat, :basic_auth_password, old_password)
        Application.put_env(:pinchflat, :expose_feed_endpoints, old_expose_feed_endpoints)
      end)

      :ok
    end

    test "uses basic auth when expose_feed_endpoints is false" do
      Application.put_env(:pinchflat, :basic_auth_username, "user")
      Application.put_env(:pinchflat, :basic_auth_password, "pass")
      Application.put_env(:pinchflat, :expose_feed_endpoints, false)

      conn = Plugs.maybe_basic_auth(build_conn(), [])

      assert conn.status == 401
      assert {"www-authenticate", "Basic realm=\"Pinchflat\""} in conn.resp_headers
    end

    test "supplying the correct username and password allows access" do
      Application.put_env(:pinchflat, :basic_auth_username, "user")
      Application.put_env(:pinchflat, :basic_auth_password, "pass")
      Application.put_env(:pinchflat, :expose_feed_endpoints, false)

      encoded_auth = Plug.BasicAuth.encode_basic_auth("user", "pass")

      conn =
        build_conn()
        |> put_req_header("authorization", encoded_auth)
        |> Plugs.maybe_basic_auth([])

      # nil here means the response is unset, but that's good. It just means we're moving to the next stage
      assert conn.status == nil
    end

    test "does not use basic auth when expose_feed_endpoints is true" do
      Application.put_env(:pinchflat, :basic_auth_username, "user")
      Application.put_env(:pinchflat, :basic_auth_password, "pass")
      Application.put_env(:pinchflat, :expose_feed_endpoints, true)

      conn = Plugs.maybe_basic_auth(build_conn(), [])

      assert conn.status == nil
    end

    test "does not use basic auth when username/password aren't set" do
      Application.put_env(:pinchflat, :basic_auth_username, nil)
      Application.put_env(:pinchflat, :basic_auth_password, nil)
      Application.put_env(:pinchflat, :expose_feed_endpoints, false)

      conn = Plugs.maybe_basic_auth(build_conn(), [])

      # nil here means the response is unset, but that's good. It just means we're moving to the next stage
      assert conn.status == nil
    end
  end

  describe "basic_auth/2" do
    setup do
      old_username = Application.get_env(:pinchflat, :basic_auth_username)
      old_password = Application.get_env(:pinchflat, :basic_auth_password)

      on_exit(fn ->
        Application.put_env(:pinchflat, :basic_auth_username, old_username)
        Application.put_env(:pinchflat, :basic_auth_password, old_password)
      end)

      :ok
    end

    test "uses basic auth when both username and password are set", %{conn: conn} do
      Application.put_env(:pinchflat, :basic_auth_username, "user")
      Application.put_env(:pinchflat, :basic_auth_password, "pass")

      conn = Plugs.basic_auth(conn, [])

      assert conn.status == 401
      assert {"www-authenticate", "Basic realm=\"Pinchflat\""} in conn.resp_headers
    end

    test "providing the username and password allows access", %{conn: conn} do
      Application.put_env(:pinchflat, :basic_auth_username, "user")
      Application.put_env(:pinchflat, :basic_auth_password, "pass")

      conn =
        conn
        |> put_req_header("authorization", Plug.BasicAuth.encode_basic_auth("user", "pass"))
        |> Plugs.basic_auth([])

      # nil here means the response is unset, but that's good. It just means we're moving to the next stage
      assert conn.status == nil
    end

    test "does not use basic auth when either username or password is not set", %{conn: conn} do
      Application.put_env(:pinchflat, :basic_auth_username, nil)
      Application.put_env(:pinchflat, :basic_auth_password, "pass")

      conn = Plugs.basic_auth(conn, [])

      assert conn.status == nil
    end

    test "treats empty strings as not being set when using basic auth", %{conn: conn} do
      Application.put_env(:pinchflat, :basic_auth_username, "")
      Application.put_env(:pinchflat, :basic_auth_password, "pass")

      conn = Plugs.basic_auth(conn, [])

      assert conn.status == nil
    end
  end

  describe "allow_iframe_embed/2" do
    test "deletes the x-frame-options header", %{conn: conn} do
      conn = put_resp_header(conn, "x-frame-options", "DENY")
      assert ["DENY"] = get_resp_header(conn, "x-frame-options")

      conn = Plugs.allow_iframe_embed(conn, [])

      assert [] = get_resp_header(conn, "x-frame-options")
    end
  end

  describe "token_protected_route/2" do
    test "allows access when the route token is correct", %{conn: conn} do
      route_token = Settings.get!(:route_token)
      conn = %{conn | query_params: %{"route_token" => route_token}}

      conn = Plugs.token_protected_route(conn, [])

      # nil here means the response is unset, but that's good. It just means we're moving to the next stage
      assert conn.status == nil
    end

    test "does not allow access when the route token is incorrect", %{conn: conn} do
      conn = %{conn | query_params: %{"route_token" => "incorrect"}}

      conn = Plugs.token_protected_route(conn, [])

      assert conn.status == 401
      assert conn.resp_body == "Unauthorized"
    end

    test "does not allow access when the route token is missing", %{conn: conn} do
      conn = %{conn | query_params: %{}}

      conn = Plugs.token_protected_route(conn, [])

      assert conn.status == 401
      assert conn.resp_body == "Unauthorized"
    end
  end
end
