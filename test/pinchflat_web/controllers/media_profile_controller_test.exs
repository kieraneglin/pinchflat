defmodule PinchflatWeb.MediaProfileControllerTest do
  use PinchflatWeb.ConnCase

  import Pinchflat.ProfilesFixtures

  @create_attrs %{name: "some name", output_path_template: "some output_path_template"}
  @update_attrs %{
    name: "some updated name",
    output_path_template: "some updated output_path_template"
  }
  @invalid_attrs %{name: nil, output_path_template: nil}

  describe "index" do
    test "lists all media_profiles", %{conn: conn} do
      conn = get(conn, ~p"/media_profiles")
      assert html_response(conn, 200) =~ "Listing Media profiles"
    end
  end

  describe "new media_profile" do
    test "renders form", %{conn: conn} do
      conn = get(conn, ~p"/media_profiles/new")
      assert html_response(conn, 200) =~ "New Media profile"
    end
  end

  describe "create media_profile" do
    test "redirects to show when data is valid", %{conn: conn} do
      conn = post(conn, ~p"/media_profiles", media_profile: @create_attrs)

      assert %{id: id} = redirected_params(conn)
      assert redirected_to(conn) == ~p"/media_profiles/#{id}"

      conn = get(conn, ~p"/media_profiles/#{id}")
      assert html_response(conn, 200) =~ "Media profile #{id}"
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, ~p"/media_profiles", media_profile: @invalid_attrs)
      assert html_response(conn, 200) =~ "New Media profile"
    end
  end

  describe "edit media_profile" do
    setup [:create_media_profile]

    test "renders form for editing chosen media_profile", %{
      conn: conn,
      media_profile: media_profile
    } do
      conn = get(conn, ~p"/media_profiles/#{media_profile}/edit")
      assert html_response(conn, 200) =~ "Edit Media profile"
    end
  end

  describe "update media_profile" do
    setup [:create_media_profile]

    test "redirects when data is valid", %{conn: conn, media_profile: media_profile} do
      conn = put(conn, ~p"/media_profiles/#{media_profile}", media_profile: @update_attrs)
      assert redirected_to(conn) == ~p"/media_profiles/#{media_profile}"

      conn = get(conn, ~p"/media_profiles/#{media_profile}")
      assert html_response(conn, 200) =~ "some updated name"
    end

    test "renders errors when data is invalid", %{conn: conn, media_profile: media_profile} do
      conn = put(conn, ~p"/media_profiles/#{media_profile}", media_profile: @invalid_attrs)
      assert html_response(conn, 200) =~ "Edit Media profile"
    end
  end

  describe "delete media_profile" do
    setup [:create_media_profile]

    test "deletes chosen media_profile", %{conn: conn, media_profile: media_profile} do
      conn = delete(conn, ~p"/media_profiles/#{media_profile}")
      assert redirected_to(conn) == ~p"/media_profiles"

      assert_error_sent 404, fn ->
        get(conn, ~p"/media_profiles/#{media_profile}")
      end
    end
  end

  defp create_media_profile(_) do
    media_profile = media_profile_fixture()
    %{media_profile: media_profile}
  end
end
