defmodule PinchflatWeb.PodcastControllerTest do
  use PinchflatWeb.ConnCase

  import Pinchflat.MediaFixtures
  import Pinchflat.SourcesFixtures

  describe "opml_feed" do

    test "unauthorized when no secret set", %{conn: conn} do
      Application.put_env(:pinchflat, :route_secret, "")
      conn = get(conn, ~p"/secret/the-secret/opml/feed" <> ".xml")
      assert conn.status == 401
    end

    test "unauthorized when secret incorrect", %{conn: conn} do
      Application.put_env(:pinchflat, :route_secret, "test-secret")
      conn = get(conn, ~p"/secret/invalid-secret/opml/feed" <> ".xml")
      assert conn.status == 401
    end

    test "renders the XML document", %{conn: conn} do
      source = source_fixture()
      Application.put_env(:pinchflat, :route_secret, "test-secret")
      conn = get(conn, ~p"/secret/test-secret/opml/feed" <> ".xml")

      assert conn.status == 200
      assert {"content-type", "application/opml+xml; charset=utf-8"} in conn.resp_headers
      assert {"content-disposition", "inline"} in conn.resp_headers
      assert conn.resp_body =~ ~s"http://www.example.com/sources/#{source.uuid}/feed.xml"
      assert conn.resp_body =~ "text=\"Cool and good internal name!\""
    end
  end

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

  describe "episode_image" do
    test "returns an episode image if one can be found", %{conn: conn} do
      media_item = media_item_with_attachments()

      conn = get(conn, ~p"/media/#{media_item.uuid}/episode_image" <> ".jpg")

      assert conn.status == 200
      assert {"content-type", "image/jpeg; charset=utf-8"} in conn.resp_headers
      assert conn.resp_body == File.read!(media_item.thumbnail_filepath)
    end

    test "returns 404 if an image cannot be found", %{conn: conn} do
      media_item = media_item_fixture()

      conn = get(conn, ~p"/media/#{media_item.uuid}/episode_image" <> ".jpg")

      assert conn.status == 404
      assert conn.resp_body == "Image not found"
    end
  end
end
