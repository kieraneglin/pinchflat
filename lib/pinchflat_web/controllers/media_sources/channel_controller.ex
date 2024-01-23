defmodule PinchflatWeb.MediaSources.ChannelController do
  use PinchflatWeb, :controller

  alias Pinchflat.MediaSource
  alias Pinchflat.MediaSource.Channel

  def index(conn, _params) do
    channels = MediaSource.list_channels()
    render(conn, :index, channels: channels)
  end

  def new(conn, _params) do
    changeset = MediaSource.change_channel(%Channel{})
    render(conn, :new, changeset: changeset)
  end

  def create(conn, %{"channel" => channel_params}) do
    case MediaSource.create_channel(channel_params) do
      {:ok, channel} ->
        conn
        |> put_flash(:info, "Channel created successfully.")
        |> redirect(to: ~p"/media_sources/channels/#{channel}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :new, changeset: changeset)
    end
  end

  def show(conn, %{"id" => id}) do
    channel = MediaSource.get_channel!(id)
    render(conn, :show, channel: channel)
  end

  def edit(conn, %{"id" => id}) do
    channel = MediaSource.get_channel!(id)
    changeset = MediaSource.change_channel(channel)
    render(conn, :edit, channel: channel, changeset: changeset)
  end

  def update(conn, %{"id" => id, "channel" => channel_params}) do
    channel = MediaSource.get_channel!(id)

    case MediaSource.update_channel(channel, channel_params) do
      {:ok, channel} ->
        conn
        |> put_flash(:info, "Channel updated successfully.")
        |> redirect(to: ~p"/media_sources/channels/#{channel}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :edit, channel: channel, changeset: changeset)
    end
  end

  def delete(conn, %{"id" => id}) do
    channel = MediaSource.get_channel!(id)
    {:ok, _channel} = MediaSource.delete_channel(channel)

    conn
    |> put_flash(:info, "Channel deleted successfully.")
    |> redirect(to: ~p"/media_sources/channels")
  end
end
