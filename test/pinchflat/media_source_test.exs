defmodule Pinchflat.MediaSourceTest do
  use Pinchflat.DataCase

  alias Pinchflat.MediaSource

  describe "channels" do
    alias Pinchflat.MediaSource.Channel

    import Pinchflat.ProfilesFixtures
    import Pinchflat.MediaSourceFixtures

    @invalid_attrs %{name: nil, channel_id: nil}

    test "list_channels/0 returns all channels" do
      channel = channel_fixture()
      assert MediaSource.list_channels() == [channel]
    end

    test "get_channel!/1 returns the channel with given id" do
      channel = channel_fixture()
      assert MediaSource.get_channel!(channel.id) == channel
    end

    test "create_channel/1 with valid data creates a channel" do
      valid_attrs = %{
        name: "some name",
        channel_id: "some channel_id",
        media_profile_id: media_profile_fixture().id
      }

      assert {:ok, %Channel{} = channel} = MediaSource.create_channel(valid_attrs)
      assert channel.name == "some name"
      assert channel.channel_id == "some channel_id"
    end

    test "create_channel/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = MediaSource.create_channel(@invalid_attrs)
    end

    test "create_channel/1 enforces uniqueness of channel_id scoped to the media_profile" do
      valid_once_attrs = %{
        name: "some name",
        channel_id: "abc123",
        media_profile_id: media_profile_fixture().id
      }

      assert {:ok, %Channel{}} = MediaSource.create_channel(valid_once_attrs)
      assert {:error, %Ecto.Changeset{}} = MediaSource.create_channel(valid_once_attrs)
    end

    test "create_channel/1 lets you duplicate channel_ids as long as the media profile is different" do
      valid_attrs = %{
        name: "some name",
        channel_id: "abc123"
      }

      assert {:ok, %Channel{}} =
               MediaSource.create_channel(
                 Map.merge(valid_attrs, %{media_profile_id: media_profile_fixture().id})
               )

      assert {:ok, %Channel{}} =
               MediaSource.create_channel(
                 Map.merge(valid_attrs, %{media_profile_id: media_profile_fixture().id})
               )
    end

    test "update_channel/2 with valid data updates the channel" do
      channel = channel_fixture()
      update_attrs = %{name: "some updated name", channel_id: "some updated channel_id"}

      assert {:ok, %Channel{} = channel} = MediaSource.update_channel(channel, update_attrs)
      assert channel.name == "some updated name"
      assert channel.channel_id == "some updated channel_id"
    end

    test "update_channel/2 with invalid data returns error changeset" do
      channel = channel_fixture()
      assert {:error, %Ecto.Changeset{}} = MediaSource.update_channel(channel, @invalid_attrs)
      assert channel == MediaSource.get_channel!(channel.id)
    end

    test "delete_channel/1 deletes the channel" do
      channel = channel_fixture()
      assert {:ok, %Channel{}} = MediaSource.delete_channel(channel)
      assert_raise Ecto.NoResultsError, fn -> MediaSource.get_channel!(channel.id) end
    end

    test "change_channel/1 returns a channel changeset" do
      channel = channel_fixture()
      assert %Ecto.Changeset{} = MediaSource.change_channel(channel)
    end
  end
end
