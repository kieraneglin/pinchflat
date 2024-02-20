defmodule PinchflatWeb.MediaItems.MediaItemController do
  use PinchflatWeb, :controller

  alias Pinchflat.Media

  def show(conn, %{"id" => id}) do
    media_item = Media.get_media_item!(id)

    render(conn, :show, media_item: media_item)
  end

  def delete(conn, %{"id" => id} = params) do
    delete_files = Map.get(params, "delete_files", false)
    media_item = Media.get_media_item!(id)

    if delete_files do
      {:ok, _} = Media.delete_media_item_and_attachments(media_item)

      conn
      |> put_flash(:info, "Record and files deleted successfully.")
      |> redirect(to: ~p"/sources/#{media_item.source_id}")
    else
      {:ok, _} = Media.delete_media_item(media_item)

      conn
      |> put_flash(:info, "Record deleted successfully. Files were not deleted.")
      |> redirect(to: ~p"/sources/#{media_item.source_id}")
    end
  end
end
