defmodule PinchflatWeb.MediaProfileControllerTest do
  use PinchflatWeb.ConnCase

  import Pinchflat.MediaFixtures
  import Pinchflat.SourcesFixtures
  import Pinchflat.ProfilesFixtures

  alias Pinchflat.Repo
  alias Pinchflat.Settings

  @create_attrs %{name: "some name", output_path_template: "output_template.{{ ext }}"}
  @update_attrs %{
    name: "some updated name",
    output_path_template: "new_output_template.{{ ext }}"
  }
  @invalid_attrs %{name: nil, output_path_template: nil}

  setup do
    Settings.set!(:onboarding, false)

    :ok
  end

  describe "index" do
    test "lists all media_profiles", %{conn: conn} do
      conn = get(conn, ~p"/media_profiles")
      assert html_response(conn, 200) =~ "Media Profiles"
    end
  end

  describe "new media_profile" do
    test "renders form", %{conn: conn} do
      conn = get(conn, ~p"/media_profiles/new")
      assert html_response(conn, 200) =~ "New Media Profile"
    end

    test "renders correct layout when onboarding", %{conn: conn} do
      Settings.set!(:onboarding, true)
      conn = get(conn, ~p"/media_profiles/new")

      refute html_response(conn, 200) =~ "MENU"
    end
  end

  describe "create media_profile" do
    test "redirects to show when data is valid", %{conn: conn} do
      conn = post(conn, ~p"/media_profiles", media_profile: @create_attrs)

      assert %{id: id} = redirected_params(conn)
      assert redirected_to(conn) == ~p"/media_profiles/#{id}"

      conn = get(conn, ~p"/media_profiles/#{id}")
      assert html_response(conn, 200) =~ "Media Profile"
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, ~p"/media_profiles", media_profile: @invalid_attrs)
      assert html_response(conn, 200) =~ "New Media Profile"
    end

    test "redirects to onboarding when onboarding", %{conn: conn} do
      Settings.set!(:onboarding, true)
      conn = post(conn, ~p"/media_profiles", media_profile: @create_attrs)

      assert redirected_to(conn) == ~p"/?onboarding=1"
    end

    test "renders correct layout on error when onboarding", %{conn: conn} do
      Settings.set!(:onboarding, true)
      conn = post(conn, ~p"/media_profiles", media_profile: @invalid_attrs)

      refute html_response(conn, 200) =~ "MENU"
    end
  end

  describe "edit media_profile" do
    setup [:create_media_profile]

    test "renders form for editing chosen media_profile", %{
      conn: conn,
      media_profile: media_profile
    } do
      conn = get(conn, ~p"/media_profiles/#{media_profile}/edit")
      assert html_response(conn, 200) =~ "Edit Media Profile"
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
      assert html_response(conn, 200) =~ "Edit Media Profile"
    end
  end

  describe "delete media_profile when just deleting the records" do
    setup [:create_media_profile]

    test "deletes chosen media_profile and its associations", %{conn: conn, media_profile: media_profile} do
      source = source_fixture(media_profile_id: media_profile.id)
      media_item = media_item_with_attachments(%{source_id: source.id})

      conn = delete(conn, ~p"/media_profiles/#{media_profile}")
      assert redirected_to(conn) == ~p"/media_profiles"

      assert_raise Ecto.NoResultsError, fn -> Repo.reload!(media_profile) end
      assert_raise Ecto.NoResultsError, fn -> Repo.reload!(source) end
      assert_raise Ecto.NoResultsError, fn -> Repo.reload!(media_item) end
    end

    test "redirects to the media_profiles page", %{conn: conn, media_profile: media_profile} do
      conn = delete(conn, ~p"/media_profiles/#{media_profile}")

      assert redirected_to(conn) == ~p"/media_profiles"
    end

    test "doesn't delete any files", %{conn: conn, media_profile: media_profile} do
      source = source_fixture(media_profile_id: media_profile.id)
      media_item = media_item_with_attachments(%{source_id: source.id})

      delete(conn, ~p"/media_profiles/#{media_profile}")

      assert File.exists?(media_item.media_filepath)
    end
  end

  describe "delete media_profile when deleting the records and files" do
    setup [:create_media_profile]

    test "deletes chosen media_profile and its associations", %{conn: conn, media_profile: media_profile} do
      source = source_fixture(media_profile_id: media_profile.id)
      media_item = media_item_with_attachments(%{source_id: source.id})

      conn = delete(conn, ~p"/media_profiles/#{media_profile}?delete_files=true")
      assert redirected_to(conn) == ~p"/media_profiles"

      assert_raise Ecto.NoResultsError, fn -> Repo.reload!(media_profile) end
      assert_raise Ecto.NoResultsError, fn -> Repo.reload!(source) end
      assert_raise Ecto.NoResultsError, fn -> Repo.reload!(media_item) end
    end

    test "redirects to the media_profiles page", %{conn: conn, media_profile: media_profile} do
      conn = delete(conn, ~p"/media_profiles/#{media_profile}?delete_files=true")

      assert redirected_to(conn) == ~p"/media_profiles"
    end

    test "deletes the files", %{conn: conn, media_profile: media_profile} do
      source = source_fixture(media_profile_id: media_profile.id)
      media_item = media_item_with_attachments(%{source_id: source.id})

      delete(conn, ~p"/media_profiles/#{media_profile}?delete_files=true")

      refute File.exists?(media_item.media_filepath)
    end
  end

  defp create_media_profile(_) do
    media_profile = media_profile_fixture()

    %{media_profile: media_profile}
  end
end
