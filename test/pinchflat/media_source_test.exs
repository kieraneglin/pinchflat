defmodule Pinchflat.MediaSourceTest do
  use Pinchflat.DataCase

  alias Pinchflat.MediaSource
  alias Pinchflat.MediaSource.Channel

  import Pinchflat.ProfilesFixtures
  import Pinchflat.MediaSourceFixtures

  @invalid_channel_attrs %{name: nil, channel_id: nil}

  describe "list_channels/0" do
    test "it returns all channels" do
      channel = channel_fixture()
      assert MediaSource.list_channels() == [channel]
    end
  end

  describe "get_channel!/1" do
    test "it returns the channel with given id" do
      channel = channel_fixture()
      assert MediaSource.get_channel!(channel.id) == channel
    end
  end

  describe "create_channel/1" do
    test "creates a channel with valid data" do
      valid_attrs = %{
        name: "some name",
        channel_id: "some channel_id",
        media_profile_id: media_profile_fixture().id
      }

      assert {:ok, %Channel{} = channel} = MediaSource.create_channel(valid_attrs)
      assert channel.name == "some name"
      assert channel.channel_id == "some channel_id"
    end

    test "creation with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = MediaSource.create_channel(@invalid_channel_attrs)
    end

    test "creation enforces uniqueness of channel_id scoped to the media_profile" do
      valid_once_attrs = %{
        name: "some name",
        channel_id: "abc123",
        media_profile_id: media_profile_fixture().id
      }

      assert {:ok, %Channel{}} = MediaSource.create_channel(valid_once_attrs)
      assert {:error, %Ecto.Changeset{}} = MediaSource.create_channel(valid_once_attrs)
    end

    test "creation lets you duplicate channel_ids as long as the media profile is different" do
      valid_attrs = %{
        name: "some name",
        channel_id: "abc123"
      }

      channel_1_attrs = Map.merge(valid_attrs, %{media_profile_id: media_profile_fixture().id})
      channel_2_attrs = Map.merge(valid_attrs, %{media_profile_id: media_profile_fixture().id})

      assert {:ok, %Channel{}} = MediaSource.create_channel(channel_1_attrs)
      assert {:ok, %Channel{}} = MediaSource.create_channel(channel_2_attrs)
    end
  end

  describe "create_channel_from_url/2" do
    import Mox

    setup :verify_on_exit!

    test "it creates a channel with valid data" do
      channel_url = "https://www.youtube.com/c/TheUselessTrials"
      valid_attrs = %{media_profile_id: media_profile_fixture().id}

      expect(YtDlpRunnerMock, :run, fn ^channel_url, _opts ->
        {:ok, "{\"channel\": \"TheUselessTrials\", \"channel_id\": \"UCQH2\"}"}
      end)

      assert {:ok, %Channel{} = channel} =
               MediaSource.create_channel_from_url(channel_url, valid_attrs)

      assert channel.name == "TheUselessTrials"
      assert channel.channel_id == "UCQH2"
    end

    test "it returns an error string if the runner returns an error" do
      channel_url = "https://www.youtube.com/c/TheUselessTrials"
      valid_attrs = %{media_profile_id: media_profile_fixture().id}

      expect(YtDlpRunnerMock, :run, fn ^channel_url, _opts ->
        {:error, "Big issue", 1}
      end)

      assert {:error, "Big issue"} =
               MediaSource.create_channel_from_url(channel_url, valid_attrs)
    end

    test "creation with invalid data returns error changeset" do
      channel_url = "https://www.youtube.com/c/TheUselessTrials"
      invalid_attrs = %{media_profile_id: nil}

      expect(YtDlpRunnerMock, :run, fn ^channel_url, _opts ->
        {:ok, "{\"channel\": \"TheUselessTrials\", \"channel_id\": \"UCQH2\"}"}
      end)

      assert {:error, %Ecto.Changeset{}} =
               MediaSource.create_channel_from_url(channel_url, invalid_attrs)
    end
  end

  describe "update_channel/2" do
    test "updates with valid data updates the channel" do
      channel = channel_fixture()
      update_attrs = %{name: "some updated name", channel_id: "some updated channel_id"}

      assert {:ok, %Channel{} = channel} = MediaSource.update_channel(channel, update_attrs)
      assert channel.name == "some updated name"
      assert channel.channel_id == "some updated channel_id"
    end

    test "updates with invalid data returns error changeset" do
      channel = channel_fixture()

      assert {:error, %Ecto.Changeset{}} =
               MediaSource.update_channel(channel, @invalid_channel_attrs)

      assert channel == MediaSource.get_channel!(channel.id)
    end
  end

  describe "delete_channel/1" do
    test "it deletes the channel" do
      channel = channel_fixture()
      assert {:ok, %Channel{}} = MediaSource.delete_channel(channel)
      assert_raise Ecto.NoResultsError, fn -> MediaSource.get_channel!(channel.id) end
    end

    test "it returns a channel changeset" do
      channel = channel_fixture()
      assert %Ecto.Changeset{} = MediaSource.change_channel(channel)
    end
  end
end
