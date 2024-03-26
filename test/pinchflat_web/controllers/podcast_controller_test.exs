defmodule PinchflatWeb.PodcastControllerTest do
  use PinchflatWeb.ConnCase

  import Pinchflat.SourcesFixtures

  describe "rss_feed" do
    test "renders the XML document", %{conn: conn} do
      source = source_fixture()

      conn = get(conn, ~p"/sources/#{source.uuid}/feed" <> ".xml")

      assert conn.status == 200
      assert {"content-type", "application/rss+xml; charset=utf-8"} in conn.resp_headers
      assert {"content-disposition", "inline"} in conn.resp_headers
    end
  end

  describe "feed_image" do
    test "returns a feed image if one can be found", %{conn: conn} do
      source = source_with_metadata_attachments()

      conn = get(conn, ~p"/sources/#{source.uuid}/feed_image" <> ".jpg")

      assert conn.status == 200
      assert {"content-type", "image/jpeg; charset=utf-8"} in conn.resp_headers
      assert conn.resp_body == File.read!(source.metadata.poster_filepath)
    end

    test "returns 404 if an image cannot be found", %{conn: conn} do
      source = source_fixture()

      conn = get(conn, ~p"/sources/#{source.uuid}/feed_image" <> ".jpg")

      assert conn.status == 404
      assert conn.resp_body == "Image not found"
    end
  end
end
