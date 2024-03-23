defmodule PinchflatWeb.MediaItemControllerTest do
  use PinchflatWeb.ConnCase

  import Pinchflat.MediaFixtures

  alias Pinchflat.Repo

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

  describe "streaming media" do
    test "returns 404 if the media isn't found", %{conn: conn} do
      media_item = media_item_fixture()
      conn = get(conn, ~p"/media/#{media_item.uuid}/stream")

      assert conn.status == 404
    end

    test "automatically sets the content type", %{conn: conn} do
      media_item = media_item_with_attachments()
      conn = get(conn, ~p"/media/#{media_item.uuid}/stream")

      assert {"content-type", "video/mp4; charset=utf-8"} in conn.resp_headers
    end

    test "sets the content length", %{conn: conn} do
      media_item = media_item_with_attachments()
      filesize = File.stat!(media_item.media_filepath).size

      conn = get(conn, ~p"/media/#{media_item.uuid}/stream")

      assert {"content-length", to_string(filesize)} in conn.resp_headers
    end
  end

  describe "streaming media when range is valid" do
    setup do
      media_item = media_item_with_attachments()

      %{media_item: media_item}
    end

    test "sets the correct status and headers", %{conn: conn, media_item: media_item} do
      filesize = File.stat!(media_item.media_filepath).size

      conn =
        conn
        |> put_req_header("range", "bytes=0-100")
        |> get(~p"/media/#{media_item.uuid}/stream")

      assert conn.status == 206
      assert {"content-range", "bytes 0-100/#{filesize}"} in conn.resp_headers
      assert {"content-length", "101"} in conn.resp_headers
    end

    test "streams the specified range", %{conn: conn, media_item: media_item} do
      conn =
        conn
        |> put_req_header("range", "bytes=0-100")
        |> get(~p"/media/#{media_item.uuid}/stream")

      assert byte_size(conn.resp_body) == 101
    end

    test "supports range offsets", %{conn: conn, media_item: media_item} do
      contents = File.read!(media_item.media_filepath)
      expected = String.slice(contents, 100..200)

      conn =
        conn
        |> put_req_header("range", "bytes=100-200")
        |> get(~p"/media/#{media_item.uuid}/stream")

      assert conn.resp_body == expected
    end

    test "returns as expected if the requested range is larger than the file", %{conn: conn, media_item: media_item} do
      contents = File.read!(media_item.media_filepath)
      filesize = File.stat!(media_item.media_filepath).size

      conn =
        conn
        |> put_req_header("range", "bytes=0-#{filesize * 10}")
        |> get(~p"/media/#{media_item.uuid}/stream")

      assert conn.resp_body == contents
      assert {"content-range", "bytes 0-#{filesize - 1}/#{filesize}"} in conn.resp_headers
      assert {"content-length", to_string(filesize)} in conn.resp_headers
    end

    test "supports endless ranges", %{conn: conn, media_item: media_item} do
      contents = File.read!(media_item.media_filepath)

      conn =
        conn
        |> put_req_header("range", "bytes=0-")
        |> get(~p"/media/#{media_item.uuid}/stream")

      assert conn.resp_body == contents
    end

    test "supports endless ranges with offsets", %{conn: conn, media_item: media_item} do
      contents = File.read!(media_item.media_filepath)
      {_, expected} = String.split_at(contents, 100)

      conn =
        conn
        |> put_req_header("range", "bytes=100-")
        |> get(~p"/media/#{media_item.uuid}/stream")

      assert conn.resp_body == expected
    end
  end

  describe "streaming media when range is invalid or not present" do
    setup do
      media_item = media_item_with_attachments()

      %{media_item: media_item}
    end

    test "sets the correct status and headers", %{conn: conn, media_item: media_item} do
      filesize = File.stat!(media_item.media_filepath).size

      conn = get(conn, ~p"/media/#{media_item.uuid}/stream")

      assert conn.status == 200
      assert {"content-length", to_string(filesize)} in conn.resp_headers
    end

    test "streams the entire file", %{conn: conn, media_item: media_item} do
      contents = File.read!(media_item.media_filepath)

      conn = get(conn, ~p"/media/#{media_item.uuid}/stream")

      assert conn.resp_body == contents
    end

    test "doesn't blow up if the range header is invalid", %{conn: conn, media_item: media_item} do
      contents = File.read!(media_item.media_filepath)

      conn =
        conn
        |> put_req_header("range", "bytes=-")
        |> get(~p"/media/#{media_item.uuid}/stream")

      assert conn.status == 200
      assert conn.resp_body == contents
    end
  end

  defp create_media_item(_) do
    media_item = media_item_fixture()
    %{media_item: media_item}
  end
end
