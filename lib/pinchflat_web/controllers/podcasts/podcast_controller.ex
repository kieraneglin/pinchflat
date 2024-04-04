defmodule PinchflatWeb.Podcasts.PodcastController do
  use PinchflatWeb, :controller

  alias Pinchflat.Repo
  alias Pinchflat.Media.MediaQuery
  alias Pinchflat.Sources.Source
  alias Pinchflat.Podcasts.RssFeedBuilder
  alias Pinchflat.Podcasts.PodcastHelpers

  def rss_feed(conn, %{"uuid" => uuid}) do
    source = Repo.get_by!(Source, uuid: uuid)
    url_base = url(conn, ~p"/")
    xml = RssFeedBuilder.build(source, limit: 300, url_base: url_base)

    conn
    |> put_resp_content_type("application/rss+xml")
    |> put_resp_header("content-disposition", "inline")
    |> send_resp(200, xml)
  end

  def feed_image(conn, %{"uuid" => uuid}) do
    source = Repo.get_by!(Source, uuid: uuid)

    # This is used to fetch a fallback cover image
    # if the source doesn't have any usable images
    media_items =
      MediaQuery.new()
      |> MediaQuery.for_source(source)
      |> MediaQuery.with_media_filepath()
      |> Repo.maybe_limit(1)
      |> Repo.all()

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
