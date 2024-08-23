defmodule PinchflatWeb.ErrorHTMLTest do
  use PinchflatWeb.ConnCase, async: false

  # Bring render_to_string/4 for testing custom views
  import Phoenix.Template

  test "renders 404.html" do
    assert render_to_string(PinchflatWeb.ErrorHTML, "404", "html", []) =~ "404 (not found)"
  end

  test "renders 500.html" do
    assert render_to_string(PinchflatWeb.ErrorHTML, "500", "html", []) =~ "Internal Server Error"
  end
end
