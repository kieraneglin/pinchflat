defmodule PinchflatWeb.Sources.SourceLive.SourceEnableToggleTest do
  use PinchflatWeb.ConnCase

  import Phoenix.LiveViewTest

  alias PinchflatWeb.Sources.SourceLive.SourceEnableToggle

  describe "initial rendering" do
    test "renders a toggle in the on position if the source is enabled" do
      source = %{ id: 1, enabled: true }

      html = render_component(SourceEnableToggle, %{id: :foo, source: source})

      # This is checking the Alpine attrs which is a good-enough proxy for the toggle position
      assert html =~ "{ enabled: true }"
    end

    test "renders a toggle in the off position if the source is disabled" do
      source = %{ id: 1, enabled: false }

      html = render_component(SourceEnableToggle, %{id: :foo, source: source})

      assert html =~ "{ enabled: false }"
    end
  end
end
