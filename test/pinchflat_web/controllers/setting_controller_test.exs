defmodule PinchflatWeb.SettingControllerTest do
  use PinchflatWeb.ConnCase

  alias Pinchflat.Utils.FilesystemUtils

  describe "show settings" do
    test "renders the page", %{conn: conn} do
      conn = get(conn, ~p"/settings")

      assert html_response(conn, 200) =~ "Settings"
    end
  end

  describe "update settings" do
    test "saves and redirects when data is valid", %{conn: conn} do
      update_attrs = %{apprise_server: "test://server"}

      conn = put(conn, ~p"/settings", setting: update_attrs)
      assert redirected_to(conn) == ~p"/settings"

      conn = get(conn, ~p"/settings")
      assert html_response(conn, 200) =~ update_attrs[:apprise_server]
    end
  end

  describe "app_info" do
    test "renders the page", %{conn: conn} do
      conn = get(conn, ~p"/app_info")

      assert html_response(conn, 200) =~ "App Info"
    end
  end

  describe "download_logs" do
    test "downloads logs", %{conn: conn} do
      log_path = Path.join([System.tmp_dir!(), "pinchflat", "data", "pinchflat.log"])
      FilesystemUtils.write_p(log_path, "test log data")
      Application.put_env(:pinchflat, :log_path, log_path)

      conn = get(conn, ~p"/download_logs")

      assert response(conn, 200) =~ "test log data"

      Application.put_env(:pinchflat, :log_path, nil)
    end

    test "redirects when log file is not found", %{conn: conn} do
      conn = get(conn, ~p"/download_logs")

      assert redirected_to(conn) == ~p"/app_info"
      assert conn.assigns[:flash]["error"] == "Log file couldn't be found"
    end
  end
end
