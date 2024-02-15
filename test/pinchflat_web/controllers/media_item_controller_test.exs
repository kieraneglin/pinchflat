defmodule PinchflatWeb.MediaItemControllerTest do
  use PinchflatWeb.ConnCase

  import Pinchflat.MediaFixtures

  alias Pinchflat.Repo
  alias Pinchflat.Media

  describe "show media" do
    setup [:create_media_item]

    test "renders the page", %{conn: conn, media_item: media_item} do
      conn = get(conn, ~p"/sources/#{media_item.source_id}/media/#{media_item}")
      assert html_response(conn, 200) =~ "Media Item ##{media_item.id}"
    end
  end

  describe "delete media when just deleting the records" do
    setup do
      media_item = media_item_with_attachments()

      on_exit(fn ->
        Media.delete_attachments(media_item)
      end)

      %{media_item: media_item}
    end

    test "the media item is deleted", %{conn: conn, media_item: media_item} do
      delete(conn, ~p"/sources/#{media_item.source_id}/media/#{media_item.id}")

      assert_raise Ecto.NoResultsError, fn -> Repo.reload!(media_item) end
    end

    test "the files are not deleted", %{conn: conn, media_item: media_item} do
      delete(conn, ~p"/sources/#{media_item.source_id}/media/#{media_item.id}")

      assert File.exists?(media_item.media_filepath)
    end

    test "redirects to the source page", %{conn: conn, media_item: media_item} do
      conn = delete(conn, ~p"/sources/#{media_item.source_id}/media/#{media_item.id}")

      assert redirected_to(conn) == ~p"/sources/#{media_item.source_id}"
    end
  end

  describe "delete media when deleting the records and files" do
    setup do
      media_item = media_item_with_attachments()

      %{media_item: media_item}
    end

    test "the media item is deleted", %{conn: conn, media_item: media_item} do
      delete(conn, ~p"/sources/#{media_item.source_id}/media/#{media_item.id}?delete_files=true")

      assert_raise Ecto.NoResultsError, fn -> Repo.reload!(media_item) end
    end

    test "the files are deleted", %{conn: conn, media_item: media_item} do
      delete(conn, ~p"/sources/#{media_item.source_id}/media/#{media_item.id}?delete_files=true")

      refute File.exists?(media_item.media_filepath)
    end

    test "redirects to the source page", %{conn: conn, media_item: media_item} do
      conn = delete(conn, ~p"/sources/#{media_item.source_id}/media/#{media_item.id}?delete_files=true")

      assert redirected_to(conn) == ~p"/sources/#{media_item.source_id}"
    end
  end

  defp create_media_item(_) do
    media_item = media_item_fixture()
    %{media_item: media_item}
  end
end
