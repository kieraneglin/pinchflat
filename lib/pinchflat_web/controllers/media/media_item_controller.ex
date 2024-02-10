defmodule PinchflatWeb.Media.MediaItemController do
  use PinchflatWeb, :controller

  alias Pinchflat.Media

  def show(conn, %{"id" => id}) do
    media_item = Media.get_media_item!(id)

    render(conn, :show, media_item: media_item)
  end
end
