defmodule PinchflatWeb.SourceControllerTest do
  use PinchflatWeb.ConnCase
  import Mox

  import Pinchflat.ProfilesFixtures
  import Pinchflat.MediaSourceFixtures

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
      conn = get(conn, ~p"/media_sources/sources")
      assert html_response(conn, 200) =~ "Listing Sources"
    end
  end

  describe "new source" do
    test "renders form", %{conn: conn} do
      conn = get(conn, ~p"/media_sources/sources/new")
      assert html_response(conn, 200) =~ "New Source"
    end
  end

  describe "create source" do
    test "redirects to show when data is valid", %{conn: conn, create_attrs: create_attrs} do
      expect(YtDlpRunnerMock, :run, 1, &runner_function_mock/3)
      conn = post(conn, ~p"/media_sources/sources", source: create_attrs)

      assert %{id: id} = redirected_params(conn)
      assert redirected_to(conn) == ~p"/media_sources/sources/#{id}"

      conn = get(conn, ~p"/media_sources/sources/#{id}")
      assert html_response(conn, 200) =~ "Source #{id}"
    end

    test "renders errors when data is invalid", %{conn: conn, invalid_attrs: invalid_attrs} do
      conn = post(conn, ~p"/media_sources/sources", source: invalid_attrs)
      assert html_response(conn, 200) =~ "New Source"
    end
  end

  describe "edit source" do
    setup [:create_source]

    test "renders form for editing chosen source", %{conn: conn, source: source} do
      conn = get(conn, ~p"/media_sources/sources/#{source}/edit")
      assert html_response(conn, 200) =~ "Edit Source"
    end
  end

  describe "update source" do
    setup [:create_source]

    test "redirects when data is valid", %{conn: conn, source: source, update_attrs: update_attrs} do
      expect(YtDlpRunnerMock, :run, 1, &runner_function_mock/3)

      conn = put(conn, ~p"/media_sources/sources/#{source}", source: update_attrs)
      assert redirected_to(conn) == ~p"/media_sources/sources/#{source}"

      conn = get(conn, ~p"/media_sources/sources/#{source}")
      assert html_response(conn, 200) =~ "https://www.youtube.com/source/321xyz"
    end

    test "renders errors when data is invalid", %{
      conn: conn,
      source: source,
      invalid_attrs: invalid_attrs
    } do
      conn = put(conn, ~p"/media_sources/sources/#{source}", source: invalid_attrs)
      assert html_response(conn, 200) =~ "Edit Source"
    end
  end

  describe "delete source" do
    setup [:create_source]

    test "deletes chosen source", %{conn: conn, source: source} do
      conn = delete(conn, ~p"/media_sources/sources/#{source}")
      assert redirected_to(conn) == ~p"/media_sources/sources"

      assert_error_sent 404, fn ->
        get(conn, ~p"/media_sources/sources/#{source}")
      end
    end
  end

  defp create_source(_) do
    source = source_fixture()
    %{source: source}
  end

  defp runner_function_mock(_url, _opts, _ot) do
    {
      :ok,
      Phoenix.json_library().encode!(%{
        channel: "some name",
        channel_id: "some_source_id_#{:rand.uniform(1_000_000)}"
      })
    }
  end
end
