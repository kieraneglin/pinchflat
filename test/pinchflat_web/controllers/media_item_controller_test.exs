defmodule PinchflatWeb.MediaItemControllerTest do
  use PinchflatWeb.ConnCase

  import Pinchflat.MediaFixtures

  alias Pinchflat.Repo
  alias Pinchflat.Downloading.MediaDownloadWorker

  describe "show media" do
    setup [:create_media_item]

    test "renders the page", %{conn: conn, media_item: media_item} do
      conn = get(conn, ~p"/sources/#{media_item.source_id}/media/#{media_item}")

      assert html_response(conn, 200) =~ "#{media_item.title}"
    end
  end

  describe "edit media" do
    setup [:create_media_item]

    test "renders form for editing chosen media_item", %{conn: conn, media_item: media_item} do
      conn = get(conn, ~p"/sources/#{media_item.source_id}/media/#{media_item}/edit")

      assert html_response(conn, 200) =~ "Editing"
    end
  end

  describe "update media" do
    setup [:create_media_item]

    test "redirects when data is valid", %{conn: conn, media_item: media_item} do
      update_attrs = %{title: "New Title"}

      conn = put(conn, ~p"/sources/#{media_item.source_id}/media/#{media_item}", media_item: update_attrs)
      assert redirected_to(conn) == ~p"/sources/#{media_item.source_id}/media/#{media_item}"

      conn = get(conn, ~p"/sources/#{media_item.source_id}/media/#{media_item}")
      assert html_response(conn, 200) =~ update_attrs[:title]
    end

    test "renders errors when data is invalid", %{conn: conn, media_item: media_item} do
      conn = put(conn, ~p"/sources/#{media_item.source_id}/media/#{media_item}", media_item: %{title: nil})

      assert html_response(conn, 200) =~ "Editing"
    end
  end

  describe "delete media" do
    setup do
      media_item = media_item_with_attachments()

      %{media_item: media_item}
    end

    test "the media item not is deleted", %{conn: conn, media_item: media_item} do
      delete(conn, ~p"/sources/#{media_item.source_id}/media/#{media_item.id}")

      assert Repo.reload!(media_item)
    end

    test "the files are deleted", %{conn: conn, media_item: media_item} do
      delete(conn, ~p"/sources/#{media_item.source_id}/media/#{media_item.id}")

      refute File.exists?(media_item.media_filepath)
    end

    test "redirects to the source page", %{conn: conn, media_item: media_item} do
      conn = delete(conn, ~p"/sources/#{media_item.source_id}/media/#{media_item.id}")

      assert redirected_to(conn) == ~p"/sources/#{media_item.source_id}"
    end

    test "doesn't prevent re-download by default", %{conn: conn, media_item: media_item} do
      delete(conn, ~p"/sources/#{media_item.source_id}/media/#{media_item.id}")

      media_item = Repo.reload(media_item)

      refute media_item.prevent_download
    end

    test "can optionally prevent re-download", %{conn: conn, media_item: media_item} do
      delete(conn, ~p"/sources/#{media_item.source_id}/media/#{media_item.id}?prevent_download=true")

      media_item = Repo.reload(media_item)

      assert media_item.prevent_download
    end
  end

  describe "force_download" do
    test "enqueues download task", %{conn: conn} do
      media_item = media_item_fixture()

      assert [] = all_enqueued(worker: MediaDownloadWorker)
      post(conn, ~p"/sources/#{media_item.source_id}/media/#{media_item.id}/force_download")
      assert [_] = all_enqueued(worker: MediaDownloadWorker)
    end

    test "forces a download even if one wouldn't normally run", %{conn: conn} do
      media_item = media_item_fixture(%{media_filepath: nil})

      post(conn, ~p"/sources/#{media_item.source_id}/media/#{media_item.id}/force_download")
      assert [_] = all_enqueued(worker: MediaDownloadWorker, args: %{"id" => media_item.id, "force" => true})
    end

    test "redirects to the show page", %{conn: conn} do
      media_item = media_item_fixture()

      conn = post(conn, ~p"/sources/#{media_item.source_id}/media/#{media_item.id}/force_download")

      assert redirected_to(conn) == ~p"/sources/#{media_item.source_id}/media/#{media_item.id}"
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
