defmodule Pinchflat.MediaSourceTest do
  use Pinchflat.DataCase
  import Mox
  import Pinchflat.TasksFixtures
  import Pinchflat.ProfilesFixtures
  import Pinchflat.MediaSourceFixtures

  alias Pinchflat.MediaSource
  alias Pinchflat.Media.MediaItem
  alias Pinchflat.MediaSource.Channel
  alias Pinchflat.Workers.MediaIndexingWorker

  @invalid_source_attrs %{name: nil, collection_id: nil}

  setup :verify_on_exit!

  describe "list_sources/0" do
    test "it returns all sources" do
      source = source_fixture()
      assert MediaSource.list_sources() == [source]
    end
  end

  describe "get_source!/1" do
    test "it returns the source with given id" do
      source = source_fixture()
      assert MediaSource.get_source!(source.id) == source
    end
  end

  describe "create_source/1" do
    test "creates a source and adds name + ID from runner response" do
      expect(YtDlpRunnerMock, :run, &runner_function_mock/3)

      valid_attrs = %{
        media_profile_id: media_profile_fixture().id,
        original_url: "https://www.youtube.com/channel/abc123",
        collection_type: "channel"
      }

      assert {:ok, %Channel{} = source} = MediaSource.create_source(valid_attrs)
      assert source.name == "some name"
      assert String.starts_with?(source.collection_id, "some_source_id_")
    end

    test "creation with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = MediaSource.create_source(@invalid_source_attrs)
    end

    test "creation enforces uniqueness of source_id scoped to the media_profile" do
      expect(YtDlpRunnerMock, :run, 2, fn _url, _opts, _ot ->
        {:ok,
         Phoenix.json_library().encode!(%{
           channel: "some name",
           channel_id: "some_source_id_12345678"
         })}
      end)

      valid_once_attrs = %{
        media_profile_id: media_profile_fixture().id,
        original_url: "https://www.youtube.com/channel/abc123",
        collection_type: "channel"
      }

      assert {:ok, %Channel{}} = MediaSource.create_source(valid_once_attrs)
      assert {:error, %Ecto.Changeset{}} = MediaSource.create_source(valid_once_attrs)
    end

    test "creation lets you duplicate collection_ids as long as the media profile is different" do
      expect(YtDlpRunnerMock, :run, 2, fn _url, _opts, _ot ->
        {:ok,
         Phoenix.json_library().encode!(%{
           channel: "some name",
           channel_id: "some_source_id_12345678"
         })}
      end)

      valid_attrs = %{
        name: "some name",
        original_url: "https://www.youtube.com/channel/abc123",
        collection_type: "channel"
      }

      source_1_attrs = Map.merge(valid_attrs, %{media_profile_id: media_profile_fixture().id})
      source_2_attrs = Map.merge(valid_attrs, %{media_profile_id: media_profile_fixture().id})

      assert {:ok, %Channel{}} = MediaSource.create_source(source_1_attrs)
      assert {:ok, %Channel{}} = MediaSource.create_source(source_2_attrs)
    end

    test "creation will schedule the indexing task" do
      expect(YtDlpRunnerMock, :run, &runner_function_mock/3)

      valid_attrs = %{
        media_profile_id: media_profile_fixture().id,
        original_url: "https://www.youtube.com/channel/abc123",
        collection_type: "channel"
      }

      assert {:ok, %Channel{} = source} = MediaSource.create_source(valid_attrs)

      assert_enqueued(worker: MediaIndexingWorker, args: %{"id" => source.id})
    end
  end

  describe "index_media_items/1" do
    setup do
      stub(YtDlpRunnerMock, :run, fn _url, _opts, _ot -> {:ok, "video1\nvideo2\nvideo3"} end)

      {:ok, [source: source_fixture()]}
    end

    test "it creates a media_item record for each media ID returned", %{source: source} do
      assert media_items = MediaSource.index_media_items(source)

      assert Enum.count(media_items) == 3
      assert ["video1", "video2", "video3"] == Enum.map(media_items, & &1.media_id)
      assert Enum.all?(media_items, fn %MediaItem{} -> true end)
    end

    test "it attaches all media_items to the given source", %{source: source} do
      source_id = source.id
      assert media_items = MediaSource.index_media_items(source)

      assert Enum.count(media_items) == 3
      assert Enum.all?(media_items, fn %MediaItem{source_id: ^source_id} -> true end)
    end

    test "it won't duplicate media_items based on media_id and source", %{source: source} do
      _first_run = MediaSource.index_media_items(source)
      _duplicate_run = MediaSource.index_media_items(source)

      media_items = Repo.preload(source, :media_items).media_items
      assert Enum.count(media_items) == 3
    end

    test "it can duplicate media_ids for different sources", %{source: source} do
      other_source = source_fixture()

      media_items = MediaSource.index_media_items(source)
      media_items_other_source = MediaSource.index_media_items(other_source)

      assert Enum.count(media_items) == 3
      assert Enum.count(media_items_other_source) == 3

      assert Enum.map(media_items, & &1.media_id) ==
               Enum.map(media_items_other_source, & &1.media_id)
    end

    test "it returns a list of media_items or changesets", %{source: source} do
      first_run = MediaSource.index_media_items(source)
      duplicate_run = MediaSource.index_media_items(source)

      assert Enum.all?(first_run, fn %MediaItem{} -> true end)
      assert Enum.all?(duplicate_run, fn %Ecto.Changeset{} -> true end)
    end
  end

  describe "update_source/2" do
    test "updates with valid data updates the source" do
      source = source_fixture()
      update_attrs = %{name: "some updated name"}

      assert {:ok, %Channel{} = source} = MediaSource.update_source(source, update_attrs)
      assert source.name == "some updated name"
    end

    test "updating the original_url will re-fetch the source details" do
      expect(YtDlpRunnerMock, :run, &runner_function_mock/3)

      source = source_fixture()
      update_attrs = %{original_url: "https://www.youtube.com/channel/abc123"}

      assert {:ok, %Channel{} = source} = MediaSource.update_source(source, update_attrs)
      assert source.name == "some name"
      assert String.starts_with?(source.collection_id, "some_source_id_")
    end

    test "not updating the original_url will not re-fetch the source details" do
      expect(YtDlpRunnerMock, :run, 0, &runner_function_mock/3)

      source = source_fixture()
      update_attrs = %{name: "some updated name"}

      assert {:ok, %Channel{}} = MediaSource.update_source(source, update_attrs)
    end

    test "updating the index frequency will re-schedule the indexing task" do
      source = source_fixture()
      update_attrs = %{index_frequency_minutes: 123}

      assert {:ok, %Channel{} = source} = MediaSource.update_source(source, update_attrs)
      assert source.index_frequency_minutes == 123
      assert_enqueued(worker: MediaIndexingWorker, args: %{"id" => source.id})
    end

    test "not updating the index frequency will not re-schedule the indexing task" do
      source = source_fixture()
      update_attrs = %{name: "some updated name"}

      assert {:ok, %Channel{}} = MediaSource.update_source(source, update_attrs)
      refute_enqueued(worker: MediaIndexingWorker, args: %{"id" => source.id})
    end

    test "updates with invalid data returns error changeset" do
      source = source_fixture()

      assert {:error, %Ecto.Changeset{}} =
               MediaSource.update_source(source, @invalid_source_attrs)

      assert source == MediaSource.get_source!(source.id)
    end
  end

  describe "delete_source/1" do
    test "it deletes the source" do
      source = source_fixture()
      assert {:ok, %Channel{}} = MediaSource.delete_source(source)
      assert_raise Ecto.NoResultsError, fn -> MediaSource.get_source!(source.id) end
    end

    test "it returns a source changeset" do
      source = source_fixture()
      assert %Ecto.Changeset{} = MediaSource.change_source(source)
    end

    test "deletion also deletes all associated tasks" do
      source = source_fixture()
      task = task_fixture(source_id: source.id)

      assert {:ok, %Channel{}} = MediaSource.delete_source(source)
      assert_raise Ecto.NoResultsError, fn -> Repo.reload!(task) end
    end
  end

  describe "change_source/2" do
    test "it returns a changeset" do
      source = source_fixture()

      assert %Ecto.Changeset{} = MediaSource.change_source(source)
    end
  end

  describe "change_source_from_url/2" do
    test "it returns a changeset" do
      stub(YtDlpRunnerMock, :run, &runner_function_mock/3)
      source = source_fixture()

      assert %Ecto.Changeset{} = MediaSource.change_source_from_url(source, %{})
    end

    test "it does not fetch source details if the original_url isn't in the changeset" do
      expect(YtDlpRunnerMock, :run, 0, &runner_function_mock/3)

      changeset = MediaSource.change_source_from_url(%Channel{}, %{name: "some updated name"})

      assert %Ecto.Changeset{} = changeset
    end

    test "it fetches source details if the original_url is in the changeset" do
      expect(YtDlpRunnerMock, :run, &runner_function_mock/3)

      changeset =
        MediaSource.change_source_from_url(%Channel{}, %{
          original_url: "https://www.youtube.com/channel/abc123"
        })

      assert %Ecto.Changeset{} = changeset
    end

    test "it adds source details to the changeset, keeping the orignal details" do
      expect(YtDlpRunnerMock, :run, &runner_function_mock/3)

      media_profile = media_profile_fixture()
      media_profile_id = media_profile.id

      changeset =
        MediaSource.change_source_from_url(%Channel{}, %{
          original_url: "https://www.youtube.com/channel/abc123",
          media_profile_id: media_profile.id
        })

      assert %Ecto.Changeset{} = changeset
      assert String.starts_with?(changeset.changes.collection_id, "some_source_id_")

      assert %{
               name: "some name",
               media_profile_id: ^media_profile_id,
               original_url: "https://www.youtube.com/channel/abc123"
             } = changeset.changes
    end

    test "it adds an error to the changeset if the runner fails" do
      expect(YtDlpRunnerMock, :run, 1, fn _url, _opts, _ot ->
        {:error, "some error", 1}
      end)

      changeset =
        MediaSource.change_source_from_url(%Channel{}, %{
          original_url: "https://www.youtube.com/channel/abc123"
        })

      assert %Ecto.Changeset{} = changeset
      assert errors_on(changeset).original_url == ["could not fetch channel details from URL"]
    end
  end

  defp runner_function_mock(_url, _opts, _ot) do
    {
      :ok,
      Phoenix.json_library().encode!(%{
        channel: "some name",
        channel_id: "some_source_id_#{:rand.uniform(1_000_000)}"
      })
    }
  end
end
