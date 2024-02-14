defmodule PinchflatWeb.SearchControllerTest do
  use PinchflatWeb.ConnCase

  describe "show search" do
    test "renders the page", %{conn: conn} do
      conn = get(conn, ~p"/search")
      assert html_response(conn, 200) =~ "Results"
    end
  end
end
