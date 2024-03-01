defmodule PinchflatWeb.SourceControllerTest do
  use PinchflatWeb.ConnCase
  import Mox

  import Pinchflat.MediaFixtures
  import Pinchflat.SourcesFixtures
  import Pinchflat.ProfilesFixtures

  alias Pinchflat.Repo

  setup do
    media_profile = media_profile_fixture()

    {
      :ok,
      %{
        create_attrs: %{
          media_profile_id: media_profile.id,
          collection_type: "channel",
          original_url: "https://www.youtube.com/source/abc123"
        },
        update_attrs: %{
          original_url: "https://www.youtube.com/source/321xyz"
        },
        invalid_attrs: %{original_url: nil, media_profile_id: nil}
      }
    }
  end

  setup :verify_on_exit!

  describe "index" do
    test "lists all sources", %{conn: conn} do
      conn = get(conn, ~p"/sources")
      assert html_response(conn, 200) =~ "Sources"
    end
  end

  describe "new source" do
    test "renders form", %{conn: conn} do
      conn = get(conn, ~p"/sources/new")
      assert html_response(conn, 200) =~ "New Source"
    end

    test "renders correct layout when onboarding", %{session_conn: session_conn} do
      session_conn =
        session_conn
        |> put_session(:onboarding, true)
        |> get(~p"/sources/new")

      refute html_response(session_conn, 200) =~ "MENU"
    end
  end

  describe "create source" do
    test "redirects to show when data is valid", %{conn: conn, create_attrs: create_attrs} do
      expect(YtDlpRunnerMock, :run, 1, &runner_function_mock/3)
      conn = post(conn, ~p"/sources", source: create_attrs)

      assert %{id: id} = redirected_params(conn)
      assert redirected_to(conn) == ~p"/sources/#{id}"

      conn = get(conn, ~p"/sources/#{id}")
      assert html_response(conn, 200) =~ "Source"
    end

    test "renders errors when data is invalid", %{conn: conn, invalid_attrs: invalid_attrs} do
      conn = post(conn, ~p"/sources", source: invalid_attrs)
      assert html_response(conn, 200) =~ "New Source"
    end

    test "redirects to onboarding when onboarding", %{session_conn: session_conn, create_attrs: create_attrs} do
      expect(YtDlpRunnerMock, :run, 1, &runner_function_mock/3)

      session_conn =
        session_conn
        |> put_session(:onboarding, true)
        |> post(~p"/sources", source: create_attrs)

      assert redirected_to(session_conn) == ~p"/?onboarding=1"
    end

    test "renders correct layout on error when onboarding", %{session_conn: session_conn, invalid_attrs: invalid_attrs} do
      session_conn =
        session_conn
        |> put_session(:onboarding, true)
        |> post(~p"/sources", source: invalid_attrs)

      refute html_response(session_conn, 200) =~ "MENU"
    end
  end

  describe "edit source" do
    setup [:create_source]

    test "renders form for editing chosen source", %{conn: conn, source: source} do
      conn = get(conn, ~p"/sources/#{source}/edit")
      assert html_response(conn, 200) =~ "Edit Source"
    end
  end

  describe "update source" do
    setup [:create_source]

    test "redirects when data is valid", %{conn: conn, source: source, update_attrs: update_attrs} do
      expect(YtDlpRunnerMock, :run, 1, &runner_function_mock/3)

      conn = put(conn, ~p"/sources/#{source}", source: update_attrs)
      assert redirected_to(conn) == ~p"/sources/#{source}"

      conn = get(conn, ~p"/sources/#{source}")
      assert html_response(conn, 200) =~ "https://www.youtube.com/source/321xyz"
    end

    test "renders errors when data is invalid", %{
      conn: conn,
      source: source,
      invalid_attrs: invalid_attrs
    } do
      conn = put(conn, ~p"/sources/#{source}", source: invalid_attrs)
      assert html_response(conn, 200) =~ "Edit Source"
    end
  end

  describe "delete source when just deleting the records" do
    setup [:create_source]

    test "deletes chosen source and media_items", %{conn: conn, source: source, media_item: media_item} do
      delete(conn, ~p"/sources/#{source}")

      assert_raise Ecto.NoResultsError, fn -> Repo.reload!(source) end
      assert_raise Ecto.NoResultsError, fn -> Repo.reload!(media_item) end
    end

    test "redirects to the sources page", %{conn: conn, source: source} do
      conn = delete(conn, ~p"/sources/#{source}")
      assert redirected_to(conn) == ~p"/sources"
    end

    test "does not delete the files", %{conn: conn, source: source, media_item: media_item} do
      delete(conn, ~p"/sources/#{source}")
      assert File.exists?(media_item.media_filepath)
    end
  end

  describe "delete source when deleting the records and files" do
    setup [:create_source]

    test "deletes chosen source and media_items", %{conn: conn, source: source, media_item: media_item} do
      delete(conn, ~p"/sources/#{source}?delete_files=true")

      assert_raise Ecto.NoResultsError, fn -> Repo.reload!(source) end
      assert_raise Ecto.NoResultsError, fn -> Repo.reload!(media_item) end
    end

    test "redirects to the sources page", %{conn: conn, source: source} do
      conn = delete(conn, ~p"/sources/#{source}?delete_files=true")
      assert redirected_to(conn) == ~p"/sources"
    end

    test "deletes the files", %{conn: conn, source: source, media_item: media_item} do
      delete(conn, ~p"/sources/#{source}?delete_files=true")
      refute File.exists?(media_item.media_filepath)
    end
  end

  defp create_source(_) do
    source = source_fixture()
    media_item = media_item_with_attachments(%{source_id: source.id})

    %{source: source, media_item: media_item}
  end

  defp runner_function_mock(_url, _opts, _ot) do
    {
      :ok,
      Phoenix.json_library().encode!(%{
        channel: "some channel name",
        channel_id: "some_channel_id_#{:rand.uniform(1_000_000)}",
        playlist_id: "some_playlist_id_#{:rand.uniform(1_000_000)}",
        playlist_title: "some playlist name"
      })
    }
  end
end
