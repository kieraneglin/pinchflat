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
    {:ok, _} = Media.delete_media_item(media_item, delete_files: delete_files)

    flash_message =
      if delete_files do
        "Record and files deleted successfully."
      else
        "Record deleted successfully. Files were not deleted."
      end

    conn
    |> put_flash(:info, flash_message)
    |> redirect(to: ~p"/sources/#{media_item.source_id}")
  end
end
