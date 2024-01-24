defmodule Pinchflat.MediaSourceTest do
  use Pinchflat.DataCase
  import Mox

  alias Pinchflat.MediaSource
  alias Pinchflat.MediaSource.Channel

  import Pinchflat.ProfilesFixtures
  import Pinchflat.MediaSourceFixtures

  @invalid_channel_attrs %{name: nil, channel_id: nil}

  setup :verify_on_exit!

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
    test "creates a channel and adds name + ID from runner response" do
      expect(YtDlpRunnerMock, :run, &runner_function_mock/2)

      valid_attrs = %{
        media_profile_id: media_profile_fixture().id,
        original_url: "https://www.youtube.com/channel/abc123"
      }

      assert {:ok, %Channel{} = channel} = MediaSource.create_channel(valid_attrs)
      assert channel.name == "some name"
      assert String.starts_with?(channel.channel_id, "some_channel_id_")
    end

    test "creation with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = MediaSource.create_channel(@invalid_channel_attrs)
    end

    test "creation enforces uniqueness of channel_id scoped to the media_profile" do
      expect(YtDlpRunnerMock, :run, 2, fn _url, _opts ->
        {:ok,
         Phoenix.json_library().encode!(%{
           channel: "some name",
           channel_id: "some_channel_id_12345678"
         })}
      end)

      valid_once_attrs = %{
        media_profile_id: media_profile_fixture().id,
        original_url: "https://www.youtube.com/channel/abc123"
      }

      assert {:ok, %Channel{}} = MediaSource.create_channel(valid_once_attrs)
      assert {:error, %Ecto.Changeset{}} = MediaSource.create_channel(valid_once_attrs)
    end

    test "creation lets you duplicate channel_ids as long as the media profile is different" do
      expect(YtDlpRunnerMock, :run, 2, fn _url, _opts ->
        {:ok,
         Phoenix.json_library().encode!(%{
           channel: "some name",
           channel_id: "some_channel_id_12345678"
         })}
      end)

      valid_attrs = %{
        name: "some name",
        original_url: "https://www.youtube.com/channel/abc123"
      }

      channel_1_attrs = Map.merge(valid_attrs, %{media_profile_id: media_profile_fixture().id})
      channel_2_attrs = Map.merge(valid_attrs, %{media_profile_id: media_profile_fixture().id})

      assert {:ok, %Channel{}} = MediaSource.create_channel(channel_1_attrs)
      assert {:ok, %Channel{}} = MediaSource.create_channel(channel_2_attrs)
    end
  end

  describe "update_channel/2" do
    test "updates with valid data updates the channel" do
      channel = channel_fixture()
      update_attrs = %{name: "some updated name"}

      assert {:ok, %Channel{} = channel} = MediaSource.update_channel(channel, update_attrs)
      assert channel.name == "some updated name"
    end

    test "updating the original_url will re-fetch the channel details" do
      expect(YtDlpRunnerMock, :run, &runner_function_mock/2)

      channel = channel_fixture()
      update_attrs = %{original_url: "https://www.youtube.com/channel/abc123"}

      assert {:ok, %Channel{} = channel} = MediaSource.update_channel(channel, update_attrs)
      assert channel.name == "some name"
      assert String.starts_with?(channel.channel_id, "some_channel_id_")
    end

    test "not updating the original_url will not re-fetch the channel details" do
      expect(YtDlpRunnerMock, :run, 0, &runner_function_mock/2)

      channel = channel_fixture()
      update_attrs = %{name: "some updated name"}

      assert {:ok, %Channel{}} = MediaSource.update_channel(channel, update_attrs)
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

  describe "change_channel/2" do
    test "it returns a changeset" do
      channel = channel_fixture()

      assert %Ecto.Changeset{} = MediaSource.change_channel(channel)
    end
  end

  describe "change_channel_from_url/2" do
    test "it returns a changeset" do
      stub(YtDlpRunnerMock, :run, &runner_function_mock/2)
      channel = channel_fixture()

      assert %Ecto.Changeset{} = MediaSource.change_channel_from_url(channel)
    end

    test "it does not fetch channel details if the original_url isn't in the changeset" do
      expect(YtDlpRunnerMock, :run, 0, &runner_function_mock/2)

      changeset = MediaSource.change_channel_from_url(%Channel{}, %{name: "some updated name"})

      assert %Ecto.Changeset{} = changeset
    end

    test "it fetches channel details if the original_url is in the changeset" do
      expect(YtDlpRunnerMock, :run, &runner_function_mock/2)

      changeset =
        MediaSource.change_channel_from_url(%Channel{}, %{
          original_url: "https://www.youtube.com/channel/abc123"
        })

      assert %Ecto.Changeset{} = changeset
    end

    test "it adds channel details to the changeset, keeping the orignal details" do
      expect(YtDlpRunnerMock, :run, &runner_function_mock/2)

      media_profile = media_profile_fixture()
      media_profile_id = media_profile.id

      changeset =
        MediaSource.change_channel_from_url(%Channel{}, %{
          original_url: "https://www.youtube.com/channel/abc123",
          media_profile_id: media_profile.id
        })

      assert %Ecto.Changeset{} = changeset
      assert String.starts_with?(changeset.changes.channel_id, "some_channel_id_")

      assert %{
               name: "some name",
               media_profile_id: ^media_profile_id,
               original_url: "https://www.youtube.com/channel/abc123"
             } = changeset.changes
    end

    test "it adds an error to the changeset if the runner fails" do
      expect(YtDlpRunnerMock, :run, 1, fn _url, _opts ->
        {:error, "some error", 1}
      end)

      changeset =
        MediaSource.change_channel_from_url(%Channel{}, %{
          original_url: "https://www.youtube.com/channel/abc123"
        })

      assert %Ecto.Changeset{} = changeset
      assert errors_on(changeset).original_url == ["could not fetch channel details from URL"]
    end
  end

  defp runner_function_mock(_url, _opts) do
    {
      :ok,
      Phoenix.json_library().encode!(%{
        channel: "some name",
        channel_id: "some_channel_id_#{:rand.uniform(1_000_000)}"
      })
    }
  end
end
