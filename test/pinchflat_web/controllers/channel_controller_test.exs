defmodule PinchflatWeb.ChannelControllerTest do
  use PinchflatWeb.ConnCase

  import Pinchflat.ProfilesFixtures
  import Pinchflat.MediaSourceFixtures

  setup do
    media_profile = media_profile_fixture()

    {
      :ok,
      %{
        create_attrs: %{
          name: "some name",
          channel_id: "some channel_id",
          media_profile_id: media_profile.id
        },
        update_attrs: %{name: "some updated name", channel_id: "some updated channel_id"},
        invalid_attrs: %{name: nil, channel_id: nil, media_profile_id: nil}
      }
    }
  end

  describe "index" do
    test "lists all channels", %{conn: conn} do
      conn = get(conn, ~p"/media_sources/channels")
      assert html_response(conn, 200) =~ "Listing Channels"
    end
  end

  describe "new channel" do
    test "renders form", %{conn: conn} do
      conn = get(conn, ~p"/media_sources/channels/new")
      assert html_response(conn, 200) =~ "New Channel"
    end
  end

  describe "create channel" do
    test "redirects to show when data is valid", %{conn: conn, create_attrs: create_attrs} do
      conn = post(conn, ~p"/media_sources/channels", channel: create_attrs)

      assert %{id: id} = redirected_params(conn)
      assert redirected_to(conn) == ~p"/media_sources/channels/#{id}"

      conn = get(conn, ~p"/media_sources/channels/#{id}")
      assert html_response(conn, 200) =~ "Channel #{id}"
    end

    test "renders errors when data is invalid", %{conn: conn, invalid_attrs: invalid_attrs} do
      conn = post(conn, ~p"/media_sources/channels", channel: invalid_attrs)
      assert html_response(conn, 200) =~ "New Channel"
    end
  end

  describe "edit channel" do
    setup [:create_channel]

    test "renders form for editing chosen channel", %{conn: conn, channel: channel} do
      conn = get(conn, ~p"/media_sources/channels/#{channel}/edit")
      assert html_response(conn, 200) =~ "Edit Channel"
    end
  end

  describe "update channel" do
    setup [:create_channel]

    test "redirects when data is valid", %{conn: conn, channel: channel, update_attrs: update_attrs} do
      conn = put(conn, ~p"/media_sources/channels/#{channel}", channel: update_attrs)
      assert redirected_to(conn) == ~p"/media_sources/channels/#{channel}"

      conn = get(conn, ~p"/media_sources/channels/#{channel}")
      assert html_response(conn, 200) =~ "some updated name"
    end

    test "renders errors when data is invalid", %{
      conn: conn,
      channel: channel,
      invalid_attrs: invalid_attrs
    } do
      conn = put(conn, ~p"/media_sources/channels/#{channel}", channel: invalid_attrs)
      assert html_response(conn, 200) =~ "Edit Channel"
    end
  end

  describe "delete channel" do
    setup [:create_channel]

    test "deletes chosen channel", %{conn: conn, channel: channel} do
      conn = delete(conn, ~p"/media_sources/channels/#{channel}")
      assert redirected_to(conn) == ~p"/media_sources/channels"

      assert_error_sent 404, fn ->
        get(conn, ~p"/media_sources/channels/#{channel}")
      end
    end
  end

  defp create_channel(_) do
    channel = channel_fixture()
    %{channel: channel}
  end
end
