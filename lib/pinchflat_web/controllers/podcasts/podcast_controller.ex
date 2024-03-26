defmodule PinchflatWeb.Podcasts.PodcastController do
  use PinchflatWeb, :controller

  alias Pinchflat.Repo
  alias Pinchflat.Media
  alias Pinchflat.Sources.Source
  alias Pinchflat.Podcasts.RssFeedBuilder
  alias Pinchflat.Podcasts.PodcastHelpers

  def rss_feed(conn, %{"uuid" => uuid}) do
    source = Repo.get_by!(Source, uuid: uuid)
    xml = RssFeedBuilder.build(source, limit: 300)

    conn
    |> put_resp_content_type("application/rss+xml")
    |> put_resp_header("content-disposition", "inline")
    |> send_resp(200, xml)
  end

  def feed_image(conn, %{"uuid" => uuid}) do
    source = Repo.get_by!(Source, uuid: uuid)
    # This provides a fallback image if the source has none.
    # We only need one since we're using the internal metadata image which
    # we know exists.
    media_items = Media.list_downloaded_media_items_for(source, limit: 1)

    case PodcastHelpers.select_cover_image(source, media_items) do
      {:error, _} ->
        send_resp(conn, 404, "Image not found")

      {:ok, filepath} ->
        conn
        |> put_resp_content_type(MIME.from_path(filepath))
        |> send_file(200, filepath)
    end
  end
end
