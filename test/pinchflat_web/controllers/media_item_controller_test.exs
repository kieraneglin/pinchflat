defmodule PinchflatWeb.MediaItemControllerTest do
  use PinchflatWeb.ConnCase

  import Pinchflat.MediaFixtures

  describe "show media" do
    setup [:create_media_item]

    test "renders the page", %{conn: conn, media_item: media_item} do
      conn = get(conn, ~p"/media/#{media_item}")
      assert html_response(conn, 200) =~ "Media Item ##{media_item.id}"
    end
  end

  defp create_media_item(_) do
    media_item = media_item_fixture()
    %{media_item: media_item}
  end
end
