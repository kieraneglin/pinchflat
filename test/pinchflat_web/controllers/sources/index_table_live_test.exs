defmodule PinchflatWeb.Sources.IndexTableLiveTest do
  use PinchflatWeb.ConnCase

  import Phoenix.LiveViewTest
  import Pinchflat.SourcesFixtures
  import Pinchflat.ProfilesFixtures

  alias Pinchflat.Sources.Source
  alias PinchflatWeb.Sources.IndexTableLive

  describe "initial rendering" do
    test "lists all sources", %{conn: conn} do
      source = source_fixture()

      {:ok, _view, html} = live_isolated(conn, IndexTableLive)

      assert html =~ source.custom_name
    end

    test "omits sources that have marked_for_deletion_at set", %{conn: conn} do
      source = source_fixture(marked_for_deletion_at: DateTime.utc_now())

      {:ok, _view, html} = live_isolated(conn, IndexTableLive)

      refute html =~ source.custom_name
    end

    test "omits sources who's media profile has marked_for_deletion_at set", %{conn: conn} do
      media_profile = media_profile_fixture(marked_for_deletion_at: DateTime.utc_now())
      source = source_fixture(media_profile_id: media_profile.id)

      {:ok, _view, html} = live_isolated(conn, IndexTableLive)

      refute html =~ source.custom_name
    end
  end

  describe "when a source is enabled or disabled" do
    test "updates the source's enabled status", %{conn: conn} do
      source = source_fixture(enabled: true)
      {:ok, view, _html} = live_isolated(conn, IndexTableLive)

      params = %{
        "event" => "toggle_enabled",
        "id" => source.id,
        "value" => "false"
      }

      # Send an event to the server directly
      render_change(view, "formless-input", params)

      assert %{enabled: false} = Repo.get!(Source, source.id)
    end
  end
end
