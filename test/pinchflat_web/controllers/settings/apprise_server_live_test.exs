defmodule PinchflatWeb.Settings.AppriseServerLiveTest do
  use PinchflatWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Pinchflat.Settings.AppriseServerLive

  describe "initial rendering" do
    test "renders the input", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, AppriseServerLive, session: create_session(""))

      assert html =~ ~s(input type="text" name="setting[apprise_server]")
    end

    test "sets the initial value from the session", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, AppriseServerLive, session: create_session("cool-value"))

      assert html =~ ~s(value="cool-value")
    end

    test "shows a relevant button icon", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, AppriseServerLive, session: create_session(""))

      assert html =~ "hero-paper-airplane"
      refute html =~ "hero-check"
    end
  end

  describe "pressing the button" do
    setup do
      stub(AppriseRunnerMock, :run, fn _, _ -> {:ok, ""} end)

      :ok
    end

    test "sends a test message to the specified server", %{conn: conn} do
      expect(AppriseRunnerMock, :run, fn servers, args ->
        assert servers == ["cool-value"]
        assert args == [title: "Pinchflat Test", body: "This is a test message from Pinchflat"]

        {:ok, ""}
      end)

      {:ok, view, _html} = live_isolated(conn, AppriseServerLive, session: create_session("cool-value"))

      assert view
             |> element("button")
             |> render_click()
    end

    test "sets the button icon to a checkmark", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, AppriseServerLive, session: create_session("cool-value"))

      result =
        view
        |> element("button")
        |> render_click()

      refute result =~ "hero-paper-airplane"
      assert result =~ "hero-check"
    end
  end

  defp create_session(value) do
    %{"value" => value}
  end
end
