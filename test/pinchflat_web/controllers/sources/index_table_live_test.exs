defmodule PinchflatWeb.Sources.SourceLive.IndexTableLiveTest do
  use PinchflatWeb.ConnCase

  import Phoenix.LiveViewTest
  import Pinchflat.SourcesFixtures
  import Pinchflat.ProfilesFixtures

  alias Pinchflat.Sources.Source
  alias PinchflatWeb.Sources.SourceLive.IndexTableLive

  describe "initial rendering" do
    test "lists all sources", %{conn: conn} do
      source = source_fixture()

      {:ok, _view, html} = live_isolated(conn, IndexTableLive, session: create_session())

      assert html =~ source.custom_name
    end

    test "omits sources that have marked_for_deletion_at set", %{conn: conn} do
      source = source_fixture(marked_for_deletion_at: DateTime.utc_now())

      {:ok, _view, html} = live_isolated(conn, IndexTableLive, session: create_session())

      refute html =~ source.custom_name
    end

    test "omits sources who's media profile has marked_for_deletion_at set", %{conn: conn} do
      media_profile = media_profile_fixture(marked_for_deletion_at: DateTime.utc_now())
      source = source_fixture(media_profile_id: media_profile.id)

      {:ok, _view, html} = live_isolated(conn, IndexTableLive, session: create_session())

      refute html =~ source.custom_name
    end
  end

  describe "when testing sorting" do
    test "sorts by the custom_name by default", %{conn: conn} do
      source1 = source_fixture(custom_name: "Source_B")
      source2 = source_fixture(custom_name: "Source_A")

      {:ok, view, _html} = live_isolated(conn, IndexTableLive, session: create_session())
      assert render_element(view, "tbody tr:first-child") =~ source2.custom_name
      assert render_element(view, "tbody tr:last-child") =~ source1.custom_name
    end

    test "clicking the row will change the sort direction", %{conn: conn} do
      source1 = source_fixture(custom_name: "Source_B")
      source2 = source_fixture(custom_name: "Source_A")

      {:ok, view, _html} = live_isolated(conn, IndexTableLive, session: create_session())

      # Click the row to change the sort direction
      click_element(view, "th", "Name")

      assert render_element(view, "tbody tr:first-child") =~ source1.custom_name
      assert render_element(view, "tbody tr:last-child") =~ source2.custom_name
    end

    test "clicking a different row will sort by that attribute", %{conn: conn} do
      source1 = source_fixture(custom_name: "Source_A", retention_period_days: 10)
      source2 = source_fixture(custom_name: "Source_A", retention_period_days: 5)

      {:ok, view, _html} = live_isolated(conn, IndexTableLive, session: create_session())

      # Click the row to change the sort field
      click_element(view, "th", "Retention")

      assert render_element(view, "tbody tr:first-child") =~ source2.custom_name
      assert render_element(view, "tbody tr:last-child") =~ source1.custom_name

      # Click the row to again change the sort direcation
      click_element(view, "th", "Retention")
      assert render_element(view, "tbody tr:first-child") =~ source1.custom_name
      assert render_element(view, "tbody tr:last-child") =~ source2.custom_name
    end
  end

  describe "when testing pagination" do
    test "moving to the next page loads new records", %{conn: conn} do
      source1 = source_fixture(custom_name: "Source_A")
      source2 = source_fixture(custom_name: "Source_B")

      session = Map.merge(create_session(), %{"results_per_page" => 1})
      {:ok, view, _html} = live_isolated(conn, IndexTableLive, session: session)

      assert render_element(view, "tbody") =~ source1.custom_name
      refute render_element(view, "tbody") =~ source2.custom_name

      click_element(view, "span.pagination-next")

      refute render_element(view, "tbody") =~ source1.custom_name
      assert render_element(view, "tbody") =~ source2.custom_name
    end
  end

  describe "when testing the enable toggle" do
    test "updates the source's enabled status", %{conn: conn} do
      source = source_fixture(enabled: true)
      {:ok, view, _html} = live_isolated(conn, IndexTableLive, session: create_session())

      view
      |> element(".enabled_toggle_form")
      |> render_change(%{source: %{"enabled" => false}})

      assert %{enabled: false} = Repo.get!(Source, source.id)
    end
  end

  defp click_element(view, selector, text_filter \\ nil) do
    view
    |> element(selector, text_filter)
    |> render_click()
  end

  defp render_element(view, selector) do
    view
    |> element(selector)
    |> render()
  end

  defp create_session do
    %{
      "initial_sort_key" => :custom_name,
      "initial_sort_direction" => :asc,
      "results_per_page" => 10
    }
  end
end
