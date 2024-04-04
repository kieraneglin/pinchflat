defmodule PinchflatWeb.PageControllerTest do
  use PinchflatWeb.ConnCase

  alias Pinchflat.SettingsBackup

  describe "GET / when testing onboarding" do
    test "sets the onboarding setting to true when onboarding", %{conn: conn} do
      _conn = get(conn, ~p"/")
      assert SettingsBackup.get!(:onboarding)
    end

    test "displays the onboarding page when onboarding is forced", %{conn: conn} do
      SettingsBackup.set!(:onboarding, false)

      conn = get(conn, ~p"/?onboarding=1")
      assert html_response(conn, 200) =~ "Welcome to Pinchflat"
    end

    test "sets the onboarding setting to false if you pass the corrent query param", %{conn: conn} do
      conn = get(conn, ~p"/")
      assert SettingsBackup.get!(:onboarding)

      _conn = get(conn, ~p"/?onboarding=0")
      refute SettingsBackup.get!(:onboarding)
    end

    test "displays the home page when not onboarding", %{conn: conn} do
      SettingsBackup.set!(:onboarding, false)

      conn = get(conn, ~p"/")
      assert html_response(conn, 200) =~ "MENU"
    end
  end
end
