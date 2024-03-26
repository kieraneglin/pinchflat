defmodule PinchflatWeb.Podcasts.PodcastController do
  use PinchflatWeb, :controller

  alias Pinchflat.Repo
  alias Pinchflat.Media
  alias Pinchflat.Podcasts.RssFeedBuilder
  alias Pinchflat.Podcasts.PodcastHelpers

  # TODO: test
  def rss_feed(conn, %{"uuid" => uuid}) do
    # TODO: change this to UUID
    source = Repo.get_by!(Source, id: uuid)
    media_items = PodcastHelpers.persisted_media_items_for(source)
    xml = RssFeedBuilder.build(source, media_items)

    conn
    |> put_resp_content_type("application/rss+xml")
    |> put_resp_header("content-disposition", "inline")
    |> send_resp(200, xml)
  end

  # TODO: test
  def feed_image(conn, %{"uuid" => uuid}) do
    source = Repo.get_by!(Source, uuid: uuid)
    # This provides a fallback image if the source has none.
    # We only need one since we're using the internal metadata image which
    # we know exists.
    media_items = Media.list_downloaded_media_items_for(source, limit: 1)
    filepath = PodcastHelpers.select_cover_image(source, media_items)

    if filepath && File.exists?(filepath) do
      conn
      |> put_resp_content_type(MIME.from_path(filepath))
      |> send_file(200, filepath)
    else
      send_resp(conn, 404, "File not found")
    end
  end
end
