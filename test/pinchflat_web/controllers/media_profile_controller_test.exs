defmodule PinchflatWeb.MediaProfileControllerTest do
  use PinchflatWeb.ConnCase

  import Pinchflat.ProfilesFixtures

  alias Pinchflat.Repo
  alias Pinchflat.Settings
  alias Pinchflat.Profiles.MediaProfileDeletionWorker

  @create_attrs %{name: "some name", output_path_template: "output_template.{{ ext }}"}
  @update_attrs %{
    name: "some updated name",
    output_path_template: "new_output_template.{{ ext }}"
  }
  @invalid_attrs %{name: nil, output_path_template: nil}

  setup do
    Settings.set(onboarding: false)

    :ok
  end

  describe "index" do
    test "lists all media_profiles", %{conn: conn} do
      profile = media_profile_fixture()
      conn = get(conn, ~p"/media_profiles")

      assert html_response(conn, 200) =~ "Media Profiles"
      assert html_response(conn, 200) =~ profile.name
    end

    test "omits profiles that have marked_for_deletion_at set", %{conn: conn} do
      profile = media_profile_fixture(marked_for_deletion_at: DateTime.utc_now())
      conn = get(conn, ~p"/media_profiles")
      refute html_response(conn, 200) =~ profile.name
    end
  end

  describe "new media_profile" do
    test "renders form", %{conn: conn} do
      conn = get(conn, ~p"/media_profiles/new")
      assert html_response(conn, 200) =~ "New Media Profile"
    end

    test "renders correct layout when onboarding", %{conn: conn} do
      Settings.set(onboarding: true)
      conn = get(conn, ~p"/media_profiles/new")

      refute html_response(conn, 200) =~ "<span>MENU</span>"
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
      Settings.set(onboarding: true)
      conn = post(conn, ~p"/media_profiles", media_profile: @create_attrs)

      assert redirected_to(conn) == ~p"/?onboarding=1"
    end

    test "renders correct layout on error when onboarding", %{conn: conn} do
      Settings.set(onboarding: true)
      conn = post(conn, ~p"/media_profiles", media_profile: @invalid_attrs)

      refute html_response(conn, 200) =~ "MENU"
    end

    test "preloads some attributes when using a template", %{conn: conn} do
      profile = media_profile_fixture(name: "My first profile", download_subs: true, sub_langs: "de")

      conn = get(conn, ~p"/media_profiles/new", %{"template_id" => profile.id})
      assert html_response(conn, 200) =~ "New Media Profile"
      assert html_response(conn, 200) =~ profile.sub_langs
      refute html_response(conn, 200) =~ profile.name
    end
  end

  describe "edit media_profile" do
    setup [:create_media_profile]

    test "renders form for editing chosen media_profile", %{
      conn: conn,
      media_profile: media_profile
    } do
      conn = get(conn, ~p"/media_profiles/#{media_profile}/edit")
      assert html_response(conn, 200) =~ "Editing \"#{media_profile.name}\""
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
      assert html_response(conn, 200) =~ "Editing \"#{media_profile.name}\""
    end
  end

  describe "delete media_profile in all cases" do
    setup [:create_media_profile]

    test "redirects to the media_profiles page", %{conn: conn, media_profile: media_profile} do
      conn = delete(conn, ~p"/media_profiles/#{media_profile}")

      assert redirected_to(conn) == ~p"/media_profiles"
    end

    test "sets marked_for_deletion_at", %{conn: conn, media_profile: media_profile} do
      delete(conn, ~p"/media_profiles/#{media_profile}")
      assert Repo.reload!(media_profile).marked_for_deletion_at
    end
  end

  describe "delete media_profile when just deleting the records" do
    setup [:create_media_profile]

    test "enqueues a job without the delete_files arg", %{conn: conn, media_profile: media_profile} do
      delete(conn, ~p"/media_profiles/#{media_profile}")

      assert [%{args: %{"delete_files" => false}}] = all_enqueued(worker: MediaProfileDeletionWorker)
    end
  end

  describe "delete media_profile when deleting the records and files" do
    setup [:create_media_profile]

    setup do
      stub(UserScriptRunnerMock, :run, fn _event_type, _data -> {:ok, "", 0} end)

      :ok
    end

    test "enqueues a job with the delete_files arg", %{conn: conn, media_profile: media_profile} do
      delete(conn, ~p"/media_profiles/#{media_profile}?delete_files=true")

      assert [%{args: %{"delete_files" => true}}] = all_enqueued(worker: MediaProfileDeletionWorker)
    end
  end

  defp create_media_profile(_) do
    media_profile = media_profile_fixture()

    %{media_profile: media_profile}
  end
end
