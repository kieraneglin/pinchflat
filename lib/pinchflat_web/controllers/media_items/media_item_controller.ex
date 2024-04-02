defmodule PinchflatWeb.MediaItems.MediaItemController do
  use PinchflatWeb, :controller

  require Logger

  alias Pinchflat.Repo
  alias Pinchflat.Media
  alias Pinchflat.Media.MediaItem

  def show(conn, %{"id" => id}) do
    media_item =
      id
      |> Media.get_media_item!()
      |> Repo.preload([:source, tasks: [:job]])

    render(conn, :show, media_item: media_item)
  end

  def delete(conn, %{"id" => id} = params) do
    prevent_download = Map.get(params, "prevent_download", false)
    media_item = Media.get_media_item!(id)
    {:ok, _} = Media.delete_media_files(media_item, prevent_download: prevent_download)

    conn
    |> put_flash(:info, "Files deleted successfully.")
    |> redirect(to: ~p"/sources/#{media_item.source_id}")
  end

  # See here for details on streaming files and range requests:
  # https://www.zeng.dev/post/2023-http-range-and-play-mp4-in-browser/
  #
  # Uses the UUID instead of the ID to avoid enumeration attacks
  # since streaming is a public endpoint (ie: no auth required)
  def stream(conn, %{"uuid" => uuid}) do
    media_item = Repo.get_by!(MediaItem, uuid: uuid)

    if File.exists?(media_item.media_filepath) do
      file_size = File.stat!(media_item.media_filepath).size
      mime_type = MIME.from_path(media_item.media_filepath)

      case parse_range(conn, file_size) do
        {:ok, {start_pos, end_pos}} ->
          Logger.debug("Streaming media item: #{media_item.uuid} from #{start_pos} to #{end_pos}")
          length = end_pos - start_pos + 1

          conn
          |> put_resp_content_type(mime_type)
          |> put_resp_header("accept-ranges", "bytes")
          |> put_resp_header("content-range", "bytes #{start_pos}-#{end_pos}/#{file_size}")
          |> put_resp_header("content-length", to_string(length))
          |> send_file(206, media_item.media_filepath, start_pos, length)

        {:error, :invalid_range} ->
          Logger.debug("Invalid range request for media item: #{media_item.uuid} - serving full file")

          conn
          |> put_resp_content_type(mime_type)
          |> put_resp_header("content-length", to_string(file_size))
          |> put_resp_header("accept-ranges", "bytes")
          |> send_file(200, media_item.media_filepath)
      end
    else
      send_resp(conn, 404, "File not found")
    end
  end

  defp parse_range(conn, file_size) do
    with [range_header | _] <- get_req_header(conn, "range"),
         ["bytes", range] <- String.split(range_header, "="),
         [start_pos, end_pos] <- String.split(range, "-") do
      validate_range(start_pos, end_pos, file_size)
    else
      _ -> {:error, :invalid_range}
    end
  end

  defp validate_range(start_pos, end_pos, file_size) do
    case {Integer.parse(start_pos), Integer.parse(end_pos)} do
      {:error, :error} ->
        {:error, :invalid_range}

      {{start_pos, _}, :error} ->
        {:ok, {start_pos, file_size - 1}}

      # See RFC7233
      {{start_pos, _}, {end_pos, _}} when end_pos >= file_size ->
        {:ok, {start_pos, file_size - 1}}

      {{start_pos, _}, {end_pos, _}} ->
        {:ok, {start_pos, end_pos}}
    end
  end
end
