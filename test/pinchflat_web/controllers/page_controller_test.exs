defmodule PinchflatWeb.PageControllerTest do
  use PinchflatWeb.ConnCase

  import Pinchflat.ProfilesFixtures
  import Pinchflat.SourcesFixtures

  describe "GET / when testing onboarding" do
    test "sets the onboarding session to true when onboarding", %{conn: conn} do
      conn = get(conn, ~p"/")
      assert get_session(conn, :onboarding)
    end

    test "displays the onboarding page when no media profiles exist", %{conn: conn} do
      conn = get(conn, ~p"/")
      assert html_response(conn, 200) =~ "Welcome to Pinchflat"
    end

    test "displays the onboarding page when no sources exist", %{conn: conn} do
      _ = media_profile_fixture()

      conn = get(conn, ~p"/")
      assert html_response(conn, 200) =~ "Welcome to Pinchflat"
    end

    test "displays the onboarding page when onboarding is forced", %{conn: conn} do
      _ = media_profile_fixture()
      _ = source_fixture()

      conn = get(conn, ~p"/?onboarding=1")
      assert html_response(conn, 200) =~ "Welcome to Pinchflat"
    end

    test "sets the onboarding session to false when not onboarding", %{conn: conn} do
      conn = get(conn, ~p"/")
      assert get_session(conn, :onboarding)

      _ = media_profile_fixture()
      _ = source_fixture()

      conn = get(conn, ~p"/")
      refute get_session(conn, :onboarding)
    end

    test "displays the home page when not onboarding", %{conn: conn} do
      _ = media_profile_fixture()
      _ = source_fixture()

      conn = get(conn, ~p"/")
      assert html_response(conn, 200) =~ "MENU"
    end
  end
end
