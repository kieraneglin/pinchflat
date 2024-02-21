defmodule PinchflatWeb.RoutingTest do
  use PinchflatWeb.ConnCase

  describe "basic_auth plug" do
    setup do
      old_username = Application.get_env(:pinchflat, :basic_auth_username)
      old_password = Application.get_env(:pinchflat, :basic_auth_password)

      on_exit(fn ->
        Application.put_env(:pinchflat, :basic_auth_username, old_username)
        Application.put_env(:pinchflat, :basic_auth_password, old_password)
      end)

      :ok
    end

    test "it uses basic auth when both username and password are set", %{conn: conn} do
      Application.put_env(:pinchflat, :basic_auth_username, "user")
      Application.put_env(:pinchflat, :basic_auth_password, "pass")

      conn = get(conn, "/")

      assert conn.status == 401
      assert {"www-authenticate", "Basic realm=\"Pinchflat\""} in conn.resp_headers
    end

    test "providing the username and password allows access", %{conn: conn} do
      Application.put_env(:pinchflat, :basic_auth_username, "user")
      Application.put_env(:pinchflat, :basic_auth_password, "pass")

      conn =
        conn
        |> put_req_header("authorization", Plug.BasicAuth.encode_basic_auth("user", "pass"))
        |> get("/")

      assert conn.status == 200
    end

    test "it does not use basic auth when either username or password is not set", %{conn: conn} do
      Application.put_env(:pinchflat, :basic_auth_username, nil)
      Application.put_env(:pinchflat, :basic_auth_password, "pass")

      conn = get(conn, "/")

      assert conn.status == 200
    end
  end
end
