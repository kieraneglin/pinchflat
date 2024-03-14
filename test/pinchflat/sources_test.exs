defmodule Pinchflat.SourcesTest do
  use Pinchflat.DataCase
  import Mox
  import Pinchflat.TasksFixtures
  import Pinchflat.MediaFixtures
  import Pinchflat.ProfilesFixtures
  import Pinchflat.SourcesFixtures

  alias Pinchflat.Sources
  alias Pinchflat.Sources.Source
  alias Pinchflat.Metadata.MetadataFileHelpers
  alias Pinchflat.Downloading.DownloadingHelpers
  alias Pinchflat.FastIndexing.FastIndexingWorker
  alias Pinchflat.Downloading.MediaDownloadWorker
  alias Pinchflat.FastIndexing.MediaIndexingWorker
  alias Pinchflat.Metadata.SourceMetadataStorageWorker
  alias Pinchflat.SlowIndexing.MediaCollectionIndexingWorker

  @invalid_source_attrs %{name: nil, collection_id: nil}

  setup :verify_on_exit!

  describe "schema" do
    test "source_metadata is deleted when the source is deleted" do
      source =
        source_fixture(%{metadata: %{metadata_filepath: "/metadata.json.gz"}})

      metadata = source.metadata
      assert {:ok, %Source{}} = Sources.delete_source(source)

      assert_raise Ecto.NoResultsError, fn ->
        Repo.reload!(metadata)
      end
    end
  end

  describe "list_sources/0" do
    test "it returns all sources" do
      source = source_fixture()
      assert Sources.list_sources() == [source]
    end
  end

  describe "list_sources_for/1" do
    test "returns all sources for a given media profile" do
      media_profile = media_profile_fixture()
      source = source_fixture(media_profile_id: media_profile.id)

      assert Sources.list_sources_for(media_profile) == [source]
    end
  end

  describe "get_source!/1" do
    test "it returns the source with given id" do
      source = source_fixture()
      assert Sources.get_source!(source.id) == source
    end
  end

  describe "create_source/1" do
    test "creates a source and adds name + ID from runner response for channels" do
      expect(YtDlpRunnerMock, :run, &channel_mock/3)

      valid_attrs = %{
        media_profile_id: media_profile_fixture().id,
        original_url: "https://www.youtube.com/channel/abc123"
      }

      assert {:ok, %Source{} = source} = Sources.create_source(valid_attrs)
      assert source.collection_name == "some channel name"
      assert String.starts_with?(source.collection_id, "some_channel_id_")
    end

    test "creates a source and adds name + ID for playlists" do
      expect(YtDlpRunnerMock, :run, &playlist_mock/3)

      valid_attrs = %{
        media_profile_id: media_profile_fixture().id,
        original_url: "https://www.youtube.com/playlist?list=abc123"
      }

      assert {:ok, %Source{} = source} = Sources.create_source(valid_attrs)
      assert source.collection_name == "some playlist name"
      assert String.starts_with?(source.collection_id, "some_playlist_id_")
    end

    test "you can specify a custom custom_name" do
      expect(YtDlpRunnerMock, :run, &channel_mock/3)

      valid_attrs = %{
        media_profile_id: media_profile_fixture().id,
        original_url: "https://www.youtube.com/channel/abc123",
        custom_name: "some custom name"
      }

      assert {:ok, %Source{} = source} = Sources.create_source(valid_attrs)

      assert source.custom_name == "some custom name"
    end

    test "friendly name is pulled from collection_name if not specified" do
      expect(YtDlpRunnerMock, :run, &channel_mock/3)

      valid_attrs = %{
        media_profile_id: media_profile_fixture().id,
        original_url: "https://www.youtube.com/channel/abc123"
      }

      assert {:ok, %Source{} = source} = Sources.create_source(valid_attrs)

      assert source.custom_name == "some channel name"
    end

    test "collection_type is inferred from source details" do
      expect(YtDlpRunnerMock, :run, &channel_mock/3)
      expect(YtDlpRunnerMock, :run, &playlist_mock/3)

      valid_attrs = %{
        media_profile_id: media_profile_fixture().id,
        original_url: "https://www.youtube.com/channel/abc123"
      }

      assert {:ok, %Source{} = source_1} = Sources.create_source(valid_attrs)
      assert {:ok, %Source{} = source_2} = Sources.create_source(valid_attrs)

      assert source_1.collection_type == :channel
      assert source_2.collection_type == :playlist
    end

    test "creation with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Sources.create_source(@invalid_source_attrs)
    end

    test "creation with invalid data fails fast and does not call the runner" do
      expect(YtDlpRunnerMock, :run, 0, &channel_mock/3)

      assert {:error, %Ecto.Changeset{}} = Sources.create_source(@invalid_source_attrs)
    end

    test "creation enforces uniqueness of collection_id scoped to the media_profile" do
      expect(YtDlpRunnerMock, :run, 2, fn _url, _opts, _ot ->
        {:ok,
         Phoenix.json_library().encode!(%{
           channel: "some channel name",
           channel_id: "some_channel_id_12345678",
           playlist_id: "some_channel_id_12345678",
           playlist_title: "some channel name - videos"
         })}
      end)

      valid_once_attrs = %{
        media_profile_id: media_profile_fixture().id,
        original_url: "https://www.youtube.com/channel/abc123"
      }

      assert {:ok, %Source{}} = Sources.create_source(valid_once_attrs)
      assert {:error, %Ecto.Changeset{}} = Sources.create_source(valid_once_attrs)
    end

    test "creation lets you duplicate collection_ids as long as the media profile is different" do
      expect(YtDlpRunnerMock, :run, 2, fn _url, _opts, _ot ->
        {:ok,
         Phoenix.json_library().encode!(%{
           channel: "some channel name",
           channel_id: "some_channel_id_12345678",
           playlist_id: "some_channel_id_12345678",
           playlist_title: "some channel name - videos"
         })}
      end)

      valid_attrs = %{
        name: "some name",
        original_url: "https://www.youtube.com/channel/abc123"
      }

      source_1_attrs = Map.merge(valid_attrs, %{media_profile_id: media_profile_fixture().id})
      source_2_attrs = Map.merge(valid_attrs, %{media_profile_id: media_profile_fixture().id})

      assert {:ok, %Source{}} = Sources.create_source(source_1_attrs)
      assert {:ok, %Source{}} = Sources.create_source(source_2_attrs)
    end

    test "creation will schedule the indexing task" do
      expect(YtDlpRunnerMock, :run, &channel_mock/3)

      valid_attrs = %{
        media_profile_id: media_profile_fixture().id,
        original_url: "https://www.youtube.com/channel/abc123"
      }

      assert {:ok, %Source{} = source} = Sources.create_source(valid_attrs)

      assert_enqueued(worker: MediaCollectionIndexingWorker, args: %{"id" => source.id})
    end

    test "creation schedules an index test even if the index frequency is 0" do
      expect(YtDlpRunnerMock, :run, &channel_mock/3)

      valid_attrs = %{
        media_profile_id: media_profile_fixture().id,
        original_url: "https://www.youtube.com/channel/abc123",
        index_frequency_minutes: 0
      }

      assert {:ok, %Source{} = source} = Sources.create_source(valid_attrs)

      assert_enqueued(worker: MediaCollectionIndexingWorker, args: %{"id" => source.id})
    end

    test "fast_index forces the index frequency to be a default value" do
      expect(YtDlpRunnerMock, :run, &channel_mock/3)

      valid_attrs = %{
        media_profile_id: media_profile_fixture().id,
        original_url: "https://www.youtube.com/channel/abc123",
        fast_index: true,
        index_frequency_minutes: 0
      }

      assert {:ok, %Source{} = source} = Sources.create_source(valid_attrs)

      assert source.index_frequency_minutes == Source.index_frequency_when_fast_indexing()
    end

    test "disabling fast index will not change the index frequency" do
      expect(YtDlpRunnerMock, :run, &channel_mock/3)

      valid_attrs = %{
        media_profile_id: media_profile_fixture().id,
        original_url: "https://www.youtube.com/channel/abc123",
        fast_index: false,
        index_frequency_minutes: 0
      }

      assert {:ok, %Source{} = source} = Sources.create_source(valid_attrs)

      assert source.index_frequency_minutes == 0
    end

    test "creating will kickoff a metadata storage worker" do
      expect(YtDlpRunnerMock, :run, &channel_mock/3)

      valid_attrs = %{
        media_profile_id: media_profile_fixture().id,
        original_url: "https://www.youtube.com/channel/abc123",
        fast_index: false,
        index_frequency_minutes: 0
      }

      assert {:ok, %Source{} = source} = Sources.create_source(valid_attrs)

      assert_enqueued(worker: SourceMetadataStorageWorker, args: %{"id" => source.id})
    end
  end

  describe "update_source/2" do
    test "updates with valid data updates the source" do
      source = source_fixture()
      update_attrs = %{collection_name: "some updated name"}

      assert {:ok, %Source{} = source} = Sources.update_source(source, update_attrs)
      assert source.collection_name == "some updated name"
    end

    test "updates with invalid data fails fast and does not call the runner" do
      expect(YtDlpRunnerMock, :run, 0, &channel_mock/3)

      source = source_fixture()

      assert {:error, %Ecto.Changeset{}} = Sources.update_source(source, @invalid_source_attrs)
    end

    test "updating the original_url will re-fetch the source details for channels" do
      expect(YtDlpRunnerMock, :run, &channel_mock/3)

      source = source_fixture()
      update_attrs = %{original_url: "https://www.youtube.com/channel/abc123"}

      assert {:ok, %Source{} = source} = Sources.update_source(source, update_attrs)
      assert source.collection_name == "some channel name"
      assert String.starts_with?(source.collection_id, "some_channel_id_")
    end

    test "updating the original_url will re-fetch the source details for playlists" do
      expect(YtDlpRunnerMock, :run, &playlist_mock/3)

      source = source_fixture()
      update_attrs = %{original_url: "https://www.youtube.com/playlist?list=abc123"}

      assert {:ok, %Source{} = source} = Sources.update_source(source, update_attrs)
      assert source.collection_name == "some playlist name"
      assert String.starts_with?(source.collection_id, "some_playlist_id_")
    end

    test "not updating the original_url will not re-fetch the source details" do
      expect(YtDlpRunnerMock, :run, 0, &channel_mock/3)

      source = source_fixture()
      update_attrs = %{name: "some updated name"}

      assert {:ok, %Source{}} = Sources.update_source(source, update_attrs)
    end

    test "updating the index frequency to >0 will re-schedule the indexing task" do
      source = source_fixture()
      update_attrs = %{index_frequency_minutes: 123}

      assert {:ok, %Source{} = source} = Sources.update_source(source, update_attrs)
      assert source.index_frequency_minutes == 123
      assert_enqueued(worker: MediaCollectionIndexingWorker, args: %{"id" => source.id})
    end

    test "updating the index frequency to 0 will not re-schedule the indexing task" do
      source = source_fixture()
      update_attrs = %{index_frequency_minutes: 0}

      assert {:ok, %Source{}} = Sources.update_source(source, update_attrs)

      refute_enqueued(worker: MediaCollectionIndexingWorker, args: %{"id" => source.id})
    end

    test "updating the index frequency to 0 will delete any pending tasks" do
      source = source_fixture()
      update_attrs = %{index_frequency_minutes: 0}

      {:ok, job_1} = Oban.insert(FastIndexingWorker.new(%{"id" => source.id}))
      task_1 = task_fixture(source_id: source.id, job_id: job_1.id)
      {:ok, job_2} = Oban.insert(MediaIndexingWorker.new(%{"id" => source.id}))
      task_2 = task_fixture(source_id: source.id, job_id: job_2.id)
      {:ok, job_3} = Oban.insert(MediaCollectionIndexingWorker.new(%{"id" => source.id}))
      task_3 = task_fixture(source_id: source.id, job_id: job_3.id)

      assert {:ok, %Source{}} = Sources.update_source(source, update_attrs)

      assert_raise Ecto.NoResultsError, fn -> Repo.reload!(task_1) end
      assert_raise Ecto.NoResultsError, fn -> Repo.reload!(task_2) end
      assert_raise Ecto.NoResultsError, fn -> Repo.reload!(task_3) end
    end

    test "not updating the index frequency will not re-schedule the indexing task or delete tasks" do
      source = source_fixture()
      task = task_fixture(source_id: source.id)
      update_attrs = %{name: "some updated name"}

      assert {:ok, %Source{}} = Sources.update_source(source, update_attrs)

      assert Repo.reload!(task)
      refute_enqueued(worker: MediaCollectionIndexingWorker, args: %{"id" => source.id})
    end

    test "enabling the download_media attribute will schedule a download task" do
      source = source_fixture(download_media: false)
      media_item = media_item_fixture(source_id: source.id, media_filepath: nil)
      update_attrs = %{download_media: true}

      refute_enqueued(worker: MediaDownloadWorker)
      assert {:ok, %Source{}} = Sources.update_source(source, update_attrs)
      assert_enqueued(worker: MediaDownloadWorker, args: %{"id" => media_item.id})
    end

    test "disabling the download_media attribute will cancel the download task" do
      source = source_fixture(download_media: true)
      media_item = media_item_fixture(source_id: source.id, media_filepath: nil)
      update_attrs = %{download_media: false}
      DownloadingHelpers.enqueue_pending_download_tasks(source)

      assert_enqueued(worker: MediaDownloadWorker, args: %{"id" => media_item.id})
      assert {:ok, %Source{}} = Sources.update_source(source, update_attrs)
      refute_enqueued(worker: MediaDownloadWorker)
    end

    test "enabling fast_index will schedule a fast indexing task" do
      source = source_fixture(fast_index: false)
      update_attrs = %{fast_index: true}

      refute_enqueued(worker: FastIndexingWorker)
      assert {:ok, %Source{}} = Sources.update_source(source, update_attrs)
      assert_enqueued(worker: FastIndexingWorker, args: %{"id" => source.id})
    end

    test "disabling fast_index will cancel the fast indexing task" do
      source = source_fixture(fast_index: true)
      update_attrs = %{fast_index: false}
      {:ok, job} = Oban.insert(FastIndexingWorker.new(%{"id" => source.id}))
      task_fixture(source_id: source.id, job_id: job.id)

      assert_enqueued(worker: FastIndexingWorker, args: %{"id" => source.id})
      assert {:ok, %Source{}} = Sources.update_source(source, update_attrs)
      refute_enqueued(worker: FastIndexingWorker)
    end

    test "updates with invalid data returns error changeset" do
      source = source_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Sources.update_source(source, @invalid_source_attrs)

      assert source == Sources.get_source!(source.id)
    end

    test "fast_index forces the index frequency to be a default value" do
      source = source_fixture(%{fast_index: true})
      update_attrs = %{index_frequency_minutes: 0}

      assert {:ok, source} = Sources.update_source(source, update_attrs)

      assert source.index_frequency_minutes == Source.index_frequency_when_fast_indexing()
    end

    test "disabling fast index will not change the index frequency" do
      source = source_fixture(%{fast_index: false})
      update_attrs = %{index_frequency_minutes: 0}

      assert {:ok, source} = Sources.update_source(source, update_attrs)

      assert source.index_frequency_minutes == 0
    end

    test "updating will kickoff a metadata storage worker" do
      source = source_fixture()
      update_attrs = %{name: "some updated name"}

      assert {:ok, %Source{} = source} = Sources.update_source(source, update_attrs)

      assert_enqueued(worker: SourceMetadataStorageWorker, args: %{"id" => source.id})
    end
  end

  describe "delete_source/2" do
    test "it deletes the source" do
      source = source_fixture()
      assert {:ok, %Source{}} = Sources.delete_source(source)
      assert_raise Ecto.NoResultsError, fn -> Sources.get_source!(source.id) end
    end

    test "it returns a source changeset" do
      source = source_fixture()
      assert %Ecto.Changeset{} = Sources.change_source(source)
    end

    test "deletion also deletes all associated tasks" do
      source = source_fixture()
      task = task_fixture(source_id: source.id)

      assert {:ok, %Source{}} = Sources.delete_source(source)
      assert_raise Ecto.NoResultsError, fn -> Repo.reload!(task) end
    end

    test "deletion also deletes all associated media items" do
      source = source_fixture()
      media_item = media_item_fixture(source_id: source.id)

      assert {:ok, %Source{}} = Sources.delete_source(source)
      assert_raise Ecto.NoResultsError, fn -> Repo.reload!(media_item) end
    end

    test "deletion does not delete media files by default" do
      source = source_fixture()
      media_item = media_item_with_attachments(%{source_id: source.id})

      assert {:ok, %Source{}} = Sources.delete_source(source)
      assert File.exists?(media_item.media_filepath)
    end

    test "deletes the source's metadata files" do
      stub(HTTPClientMock, :get, fn _url, _headers, _opts -> {:ok, ""} end)
      source = Repo.preload(source_fixture(), :metadata)

      update_attrs = %{
        metadata: %{
          metadata_filepath: MetadataFileHelpers.compress_and_store_metadata_for(source, %{})
        }
      }

      {:ok, updated_source} = Sources.update_source(source, update_attrs)

      assert {:ok, _} = Sources.delete_source(updated_source, delete_files: true)
      refute File.exists?(updated_source.metadata.metadata_filepath)
    end
  end

  describe "delete_source/2 when deleting files" do
    test "deletes source and media_items" do
      source = source_fixture()
      media_item = media_item_with_attachments(%{source_id: source.id})

      assert {:ok, %Source{}} = Sources.delete_source(source, delete_files: true)

      assert_raise Ecto.NoResultsError, fn -> Repo.reload!(media_item) end
      assert_raise Ecto.NoResultsError, fn -> Repo.reload!(source) end
    end

    test "also deletes media files" do
      source = source_fixture()
      media_item = media_item_with_attachments(%{source_id: source.id})

      assert {:ok, %Source{}} = Sources.delete_source(source, delete_files: true)

      refute File.exists?(media_item.media_filepath)
    end
  end

  describe "change_source/3" do
    test "it returns a changeset" do
      source = source_fixture()

      assert %Ecto.Changeset{} = Sources.change_source(source)
    end
  end

  describe "maybe_change_source_from_url/2" do
    test "it returns a changeset" do
      stub(YtDlpRunnerMock, :run, &channel_mock/3)
      source = source_fixture()

      assert %Ecto.Changeset{} = Sources.maybe_change_source_from_url(source, %{})
    end

    test "it does not fetch source details if the original_url isn't in the changeset" do
      expect(YtDlpRunnerMock, :run, 0, &channel_mock/3)

      changeset = Sources.maybe_change_source_from_url(%Source{}, %{name: "some updated name"})

      assert %Ecto.Changeset{} = changeset
    end

    test "it fetches source details if the original_url is in the changeset" do
      expect(YtDlpRunnerMock, :run, &channel_mock/3)

      changeset =
        Sources.maybe_change_source_from_url(%Source{}, %{
          original_url: "https://www.youtube.com/channel/abc123"
        })

      assert %Ecto.Changeset{} = changeset
    end

    test "it adds source details to the changeset, keeping the orignal details" do
      expect(YtDlpRunnerMock, :run, &channel_mock/3)

      media_profile = media_profile_fixture()
      media_profile_id = media_profile.id

      changeset =
        Sources.maybe_change_source_from_url(%Source{}, %{
          original_url: "https://www.youtube.com/channel/abc123",
          media_profile_id: media_profile.id
        })

      assert %Ecto.Changeset{} = changeset
      assert String.starts_with?(changeset.changes.collection_id, "some_channel_id_")

      assert %{
               collection_name: "some channel name",
               media_profile_id: ^media_profile_id,
               original_url: "https://www.youtube.com/channel/abc123"
             } = changeset.changes
    end

    test "it adds an error to the changeset if the runner fails" do
      expect(YtDlpRunnerMock, :run, 1, fn _url, _opts, _ot ->
        {:error, "some error", 1}
      end)

      changeset =
        Sources.maybe_change_source_from_url(%Source{}, %{
          original_url: "https://www.youtube.com/channel/abc123"
        })

      assert %Ecto.Changeset{} = changeset
      assert errors_on(changeset).original_url == ["could not fetch source details from URL"]
    end
  end

  defp playlist_mock(_url, _opts, _ot) do
    {
      :ok,
      Phoenix.json_library().encode!(%{
        channel: nil,
        channel_id: nil,
        playlist_id: "some_playlist_id_#{:rand.uniform(1_000_000)}",
        playlist_title: "some playlist name"
      })
    }
  end

  defp channel_mock(_url, _opts, _ot) do
    channel_id = "some_channel_id_#{:rand.uniform(1_000_000)}"

    {
      :ok,
      Phoenix.json_library().encode!(%{
        channel: "some channel name",
        channel_id: channel_id,
        playlist_id: channel_id,
        playlist_title: "some channel name - videos"
      })
    }
  end
end
