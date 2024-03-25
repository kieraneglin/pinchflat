defmodule PinchflatWeb.Podcasts.PodcastController do
  use PinchflatWeb, :controller

  alias Pinchflat.Repo
  alias Pinchflat.Podcasts.RssFeedBuilder
  alias Pinchflat.Podcasts.PostcastHelpers

  # TODO: test
  def rss_feed(conn, %{"uuid" => uuid}) do
    # TODO: change this to UUID
    source = Repo.get_by!(Source, id: uuid)
    media_items = PostcastHelpers.persisted_media_items_for(source)
    xml = RssFeedBuilder.build(source, media_items)

    conn
    |> put_resp_content_type("application/rss+xml")
    |> put_resp_header("content-disposition", "inline")
    |> send_resp(200, xml)
  end

  # TODO: test
  def feed_image(conn, %{"uuid" => uuid}) do
    source = Repo.get_by!(Source, uuid: uuid)
    filepath = PostcastHelpers.select_cover_image(source)

    if filepath && File.exists?(filepath) do
      conn
      |> put_resp_content_type(MIME.from_path(filepath))
      |> send_file(200, filepath)
    else
      send_resp(conn, 404, "File not found")
    end
  end
end
