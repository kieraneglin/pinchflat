defmodule PinchflatWeb.RoutingTest do
  use PinchflatWeb.ConnCase

  import Pinchflat.SourcesFixtures

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

    test "it treats empty strings as not being set when using basic auth", %{conn: conn} do
      Application.put_env(:pinchflat, :basic_auth_username, "")
      Application.put_env(:pinchflat, :basic_auth_password, "pass")

      conn = get(conn, "/")

      assert conn.status == 200
    end
  end

  describe "maybe_basic_auth plug" do
    setup do
      old_username = Application.get_env(:pinchflat, :basic_auth_username)
      old_password = Application.get_env(:pinchflat, :basic_auth_password)
      old_expore_xml_feed = Application.get_env(:pinchflat, :expose_xml_feed)

      source = source_fixture()

      on_exit(fn ->
        Application.put_env(:pinchflat, :basic_auth_username, old_username)
        Application.put_env(:pinchflat, :basic_auth_password, old_password)
        Application.put_env(:pinchflat, :expose_xml_feed, old_expore_xml_feed)
      end)

      {:ok, source: source}
    end

    test "uses basic auth when expose_xml_feed is false", %{source: source} do
      Application.put_env(:pinchflat, :basic_auth_username, "user")
      Application.put_env(:pinchflat, :basic_auth_password, "pass")
      Application.put_env(:pinchflat, :expose_xml_feed, false)

      conn = get(build_conn(), "/sources/#{source.uuid}/feed")

      assert conn.status == 401
      assert {"www-authenticate", "Basic realm=\"Pinchflat\""} in conn.resp_headers
    end

    test "does not use basic auth when expose_xml_feed is true", %{source: source} do
      Application.put_env(:pinchflat, :basic_auth_username, "user")
      Application.put_env(:pinchflat, :basic_auth_password, "pass")
      Application.put_env(:pinchflat, :expose_xml_feed, true)

      conn = get(build_conn(), "/sources/#{source.uuid}/feed")

      assert conn.status == 200
    end

    test "does not use basic auth when username/password aren't set", %{source: source} do
      Application.put_env(:pinchflat, :basic_auth_username, nil)
      Application.put_env(:pinchflat, :basic_auth_password, nil)
      Application.put_env(:pinchflat, :expose_xml_feed, false)

      conn = get(build_conn(), "/sources/#{source.uuid}/feed")

      assert conn.status == 200
    end
  end
end
