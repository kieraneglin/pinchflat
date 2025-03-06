defmodule Pinchflat.SourcesTest do
  use Pinchflat.DataCase

  import Pinchflat.TasksFixtures
  import Pinchflat.MediaFixtures
  import Pinchflat.ProfilesFixtures
  import Pinchflat.SourcesFixtures

  alias Pinchflat.Sources
  alias Pinchflat.Sources.Source
  alias Pinchflat.Utils.FilesystemUtils
  alias Pinchflat.Metadata.MetadataFileHelpers
  alias Pinchflat.Downloading.DownloadingHelpers
  alias Pinchflat.FastIndexing.FastIndexingWorker
  alias Pinchflat.Downloading.MediaDownloadWorker
  alias Pinchflat.Metadata.SourceMetadataStorageWorker
  alias Pinchflat.SlowIndexing.MediaCollectionIndexingWorker

  @invalid_source_attrs %{name: nil, collection_id: nil}

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

    test "can be JSON encoded without error" do
      source = source_fixture()

      assert {:ok, _} = Phoenix.json_library().encode(source)
    end
  end

  describe "output_path_template/1" do
    test "returns the source's override if present" do
      source = source_fixture(%{output_path_template_override: "/override/{{ title }}.{{ ext }}"})

      assert Sources.output_path_template(source) == "/override/{{ title }}.{{ ext }}"
    end

    test "returns the media profile's template if no override is present" do
      media_profile = media_profile_fixture(%{output_path_template: "/profile/{{ title }}.{{ ext }}"})
      source = source_fixture(%{media_profile_id: media_profile.id})

      assert Sources.output_path_template(source) == "/profile/{{ title }}.{{ ext }}"
    end

    test "Treats empty strings as being blank" do
      media_profile = media_profile_fixture(%{output_path_template: "/profile/{{ title }}.{{ ext }}"})
      source = source_fixture(%{media_profile_id: media_profile.id, output_path_template_override: "  "})

      assert Sources.output_path_template(source) == "/profile/{{ title }}.{{ ext }}"
    end
  end

  describe "use_cookies?/2" do
    test "returns true if the source has been set to use cookies" do
      source = source_fixture(%{cookie_behaviour: :all_operations})
      assert Sources.use_cookies?(source, :downloading)
    end

    test "returns false if the source has not been set to use cookies" do
      source = source_fixture(%{cookie_behaviour: :disabled})
      refute Sources.use_cookies?(source, :downloading)
    end

    test "returns true if the action is indexing and the source is set to :when_needed" do
      source = source_fixture(%{cookie_behaviour: :when_needed})
      assert Sources.use_cookies?(source, :indexing)
    end

    test "returns false if the action is downloading and the source is set to :when_needed" do
      source = source_fixture(%{cookie_behaviour: :when_needed})
      refute Sources.use_cookies?(source, :downloading)
    end

    test "returns true if the action is error_recovery and the source is set to :when_needed" do
      source = source_fixture(%{cookie_behaviour: :when_needed})
      assert Sources.use_cookies?(source, :error_recovery)
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

  describe "create_source/2" do
    test "automatically sets the UUID" do
      expect(YtDlpRunnerMock, :run, &channel_mock/5)

      valid_attrs = %{
        media_profile_id: media_profile_fixture().id,
        original_url: "https://www.youtube.com/channel/abc123"
      }

      assert {:ok, %Source{} = source} = Sources.create_source(valid_attrs)
      assert String.length(source.uuid) == 36
    end

    test "UUID is not writable by the user" do
      expect(YtDlpRunnerMock, :run, &channel_mock/5)

      valid_attrs = %{
        media_profile_id: media_profile_fixture().id,
        original_url: "https://www.youtube.com/channel/abc123",
        uuid: "some_uuid"
      }

      assert {:ok, %Source{} = source} = Sources.create_source(valid_attrs)
      assert String.length(source.uuid) == 36
    end

    test "creates a source and adds name + ID from runner response for channels" do
      expect(YtDlpRunnerMock, :run, &channel_mock/5)

      valid_attrs = %{
        media_profile_id: media_profile_fixture().id,
        original_url: "https://www.youtube.com/channel/abc123"
      }

      assert {:ok, %Source{} = source} = Sources.create_source(valid_attrs)
      assert source.collection_name == "some channel name"
      assert String.starts_with?(source.collection_id, "some_channel_id_")
    end

    test "creates a source and adds name + ID for playlists" do
      expect(YtDlpRunnerMock, :run, &playlist_mock/5)

      valid_attrs = %{
        media_profile_id: media_profile_fixture().id,
        original_url: "https://www.youtube.com/playlist?list=abc123"
      }

      assert {:ok, %Source{} = source} = Sources.create_source(valid_attrs)
      assert source.collection_name == "some playlist name"
      assert String.starts_with?(source.collection_id, "some_playlist_id_")
    end

    test "adds an error if the runner fails" do
      expect(YtDlpRunnerMock, :run, fn _url, :get_source_details, _opts, _ot, _addl -> {:error, "some error", 1} end)

      valid_attrs = %{
        media_profile_id: media_profile_fixture().id,
        original_url: "https://www.youtube.com/channel/abc123"
      }

      assert {:error, %Ecto.Changeset{} = changeset} = Sources.create_source(valid_attrs)
      assert "could not fetch source details from URL" in errors_on(changeset).original_url
    end

    test "adds an error if the runner succeeds but the result was invalid JSON" do
      expect(YtDlpRunnerMock, :run, fn _url, :get_source_details, _opts, _ot, _addl -> {:ok, "Not JSON"} end)

      valid_attrs = %{
        media_profile_id: media_profile_fixture().id,
        original_url: "https://www.youtube.com/channel/abc123"
      }

      assert {:error, %Ecto.Changeset{} = changeset} = Sources.create_source(valid_attrs)
      assert "could not fetch source details from URL" in errors_on(changeset).original_url
    end

    test "you can specify a custom custom_name" do
      expect(YtDlpRunnerMock, :run, &channel_mock/5)

      valid_attrs = %{
        media_profile_id: media_profile_fixture().id,
        original_url: "https://www.youtube.com/channel/abc123",
        custom_name: "some custom name"
      }

      assert {:ok, %Source{} = source} = Sources.create_source(valid_attrs)

      assert source.custom_name == "some custom name"
    end

    test "friendly name is pulled from collection_name if not specified" do
      expect(YtDlpRunnerMock, :run, &channel_mock/5)

      valid_attrs = %{
        media_profile_id: media_profile_fixture().id,
        original_url: "https://www.youtube.com/channel/abc123"
      }

      assert {:ok, %Source{} = source} = Sources.create_source(valid_attrs)

      assert source.custom_name == "some channel name"
    end

    test "creation enforces uniqueness of collection_id scoped to the media_profile and title regex" do
      expect(YtDlpRunnerMock, :run, 2, fn _url, :get_source_details, _opts, _ot, _addl ->
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
        original_url: "https://www.youtube.com/channel/abc123",
        title_filter_regex: nil
      }

      assert {:ok, %Source{}} = Sources.create_source(valid_once_attrs)
      assert {:error, %Ecto.Changeset{}} = Sources.create_source(valid_once_attrs)
    end

    test "creation lets you duplicate collection_ids and profiles as long as the regex is different" do
      expect(YtDlpRunnerMock, :run, 2, fn _url, :get_source_details, _opts, _ot, _addl ->
        {:ok,
         Phoenix.json_library().encode!(%{
           channel: "some channel name",
           channel_id: "some_channel_id_12345678",
           playlist_id: "some_channel_id_12345678",
           playlist_title: "some channel name - videos"
         })}
      end)

      valid_attrs = %{
        media_profile_id: media_profile_fixture().id,
        name: "some name",
        original_url: "https://www.youtube.com/channel/abc123"
      }

      source_1_attrs = Map.merge(valid_attrs, %{title_filter_regex: "foo"})
      source_2_attrs = Map.merge(valid_attrs, %{title_filter_regex: "bar"})

      assert {:ok, %Source{}} = Sources.create_source(source_1_attrs)
      assert {:ok, %Source{}} = Sources.create_source(source_2_attrs)
    end

    test "creation lets you duplicate collection_ids as long as the media profile is different" do
      expect(YtDlpRunnerMock, :run, 2, fn _url, :get_source_details, _opts, _ot, _addl ->
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
        original_url: "https://www.youtube.com/channel/abc123",
        title_filter_regex: "TEST"
      }

      source_1_attrs = Map.merge(valid_attrs, %{media_profile_id: media_profile_fixture().id})
      source_2_attrs = Map.merge(valid_attrs, %{media_profile_id: media_profile_fixture().id})

      assert {:ok, %Source{}} = Sources.create_source(source_1_attrs)
      assert {:ok, %Source{}} = Sources.create_source(source_2_attrs)
    end

    test "collection_type is inferred from source details" do
      expect(YtDlpRunnerMock, :run, &channel_mock/5)
      expect(YtDlpRunnerMock, :run, &playlist_mock/5)

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
      expect(YtDlpRunnerMock, :run, 0, &channel_mock/5)

      assert {:error, %Ecto.Changeset{}} = Sources.create_source(@invalid_source_attrs)
    end

    test "creation will schedule the indexing task" do
      expect(YtDlpRunnerMock, :run, &channel_mock/5)

      valid_attrs = %{
        media_profile_id: media_profile_fixture().id,
        original_url: "https://www.youtube.com/channel/abc123"
      }

      assert {:ok, %Source{} = source} = Sources.create_source(valid_attrs)

      assert_enqueued(worker: MediaCollectionIndexingWorker, args: %{"id" => source.id})
    end

    test "creation will schedule a fast indexing job if the fast_index option is set" do
      expect(YtDlpRunnerMock, :run, &channel_mock/5)

      valid_attrs = %{
        media_profile_id: media_profile_fixture().id,
        original_url: "https://www.youtube.com/channel/abc123",
        fast_index: true
      }

      assert {:ok, %Source{} = source} = Sources.create_source(valid_attrs)

      assert_enqueued(worker: FastIndexingWorker, args: %{"id" => source.id})
    end

    test "creation will not schedule a fast indexing job if the fast_index option is not set" do
      expect(YtDlpRunnerMock, :run, &channel_mock/5)

      valid_attrs = %{
        media_profile_id: media_profile_fixture().id,
        original_url: "https://www.youtube.com/channel/abc123",
        fast_index: false
      }

      assert {:ok, %Source{}} = Sources.create_source(valid_attrs)

      refute_enqueued(worker: FastIndexingWorker)
    end

    test "creation schedules an index test even if the index frequency is 0" do
      expect(YtDlpRunnerMock, :run, &channel_mock/5)

      valid_attrs = %{
        media_profile_id: media_profile_fixture().id,
        original_url: "https://www.youtube.com/channel/abc123",
        index_frequency_minutes: 0
      }

      assert {:ok, %Source{} = source} = Sources.create_source(valid_attrs)

      assert_enqueued(worker: MediaCollectionIndexingWorker, args: %{"id" => source.id})
    end

    test "fast_index forces the index frequency to be a default value" do
      expect(YtDlpRunnerMock, :run, &channel_mock/5)

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
      expect(YtDlpRunnerMock, :run, &channel_mock/5)

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
      expect(YtDlpRunnerMock, :run, &channel_mock/5)

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

  describe "create_source/2 when testing yt-dlp options" do
    test "sets use_cookies to true if the source has been set to use cookies" do
      expect(YtDlpRunnerMock, :run, fn _url, :get_source_details, _opts, _ot, addl ->
        assert Keyword.get(addl, :use_cookies)

        {:ok, playlist_return()}
      end)

      valid_attrs = %{
        media_profile_id: media_profile_fixture().id,
        original_url: "https://www.youtube.com/channel/abc123",
        cookie_behaviour: :all_operations
      }

      assert {:ok, %Source{}} = Sources.create_source(valid_attrs)
    end

    test "does not set use_cookies if the source uses cookies when needed" do
      expect(YtDlpRunnerMock, :run, fn _url, :get_source_details, _opts, _ot, addl ->
        refute Keyword.get(addl, :use_cookies)

        {:ok, playlist_return()}
      end)

      valid_attrs = %{
        media_profile_id: media_profile_fixture().id,
        original_url: "https://www.youtube.com/channel/abc123",
        cookie_behaviour: :when_needed
      }

      assert {:ok, %Source{}} = Sources.create_source(valid_attrs)
    end

    test "does not set use_cookies if the source has not been set to use cookies" do
      expect(YtDlpRunnerMock, :run, fn _url, :get_source_details, _opts, _ot, addl ->
        refute Keyword.get(addl, :use_cookies)

        {:ok, playlist_return()}
      end)

      valid_attrs = %{
        media_profile_id: media_profile_fixture().id,
        original_url: "https://www.youtube.com/channel/abc123",
        cookie_behaviour: :disabled
      }

      assert {:ok, %Source{}} = Sources.create_source(valid_attrs)
    end

    test "skips sleep interval" do
      expect(YtDlpRunnerMock, :run, fn _url, :get_source_details, _opts, _ot, addl ->
        assert Keyword.get(addl, :skip_sleep_interval)

        {:ok, playlist_return()}
      end)

      valid_attrs = %{
        media_profile_id: media_profile_fixture().id,
        original_url: "https://www.youtube.com/channel/abc123"
      }

      assert {:ok, %Source{}} = Sources.create_source(valid_attrs)
    end
  end

  describe "create_source/2 when testing its options" do
    test "run_post_commit_tasks: false won't enqueue post-commit tasks" do
      expect(YtDlpRunnerMock, :run, &channel_mock/5)

      valid_attrs = %{
        media_profile_id: media_profile_fixture().id,
        original_url: "https://www.youtube.com/channel/abc123"
      }

      assert {:ok, %Source{}} = Sources.create_source(valid_attrs, run_post_commit_tasks: false)

      refute_enqueued(worker: MediaCollectionIndexingWorker)
      refute_enqueued(worker: SourceMetadataStorageWorker)
    end
  end

  describe "update_source/3" do
    test "updates with valid data updates the source" do
      source = source_fixture()
      update_attrs = %{collection_name: "some updated name"}

      assert {:ok, %Source{} = source} = Sources.update_source(source, update_attrs)
      assert source.collection_name == "some updated name"
    end

    test "updates with invalid data fails fast and does not call the runner" do
      expect(YtDlpRunnerMock, :run, 0, &channel_mock/5)

      source = source_fixture()

      assert {:error, %Ecto.Changeset{}} = Sources.update_source(source, @invalid_source_attrs)
    end

    test "updating the original_url will re-fetch the source details for channels" do
      expect(YtDlpRunnerMock, :run, &channel_mock/5)

      source = source_fixture()
      update_attrs = %{original_url: "https://www.youtube.com/channel/abc123"}

      assert {:ok, %Source{} = source} = Sources.update_source(source, update_attrs)
      assert source.collection_name == "some channel name"
      assert String.starts_with?(source.collection_id, "some_channel_id_")
    end

    test "updating the original_url will re-fetch the source details for playlists" do
      expect(YtDlpRunnerMock, :run, &playlist_mock/5)

      source = source_fixture()
      update_attrs = %{original_url: "https://www.youtube.com/playlist?list=abc123"}

      assert {:ok, %Source{} = source} = Sources.update_source(source, update_attrs)
      assert source.collection_name == "some playlist name"
      assert String.starts_with?(source.collection_id, "some_playlist_id_")
    end

    test "not updating the original_url will not re-fetch the source details" do
      expect(YtDlpRunnerMock, :run, 0, &channel_mock/5)

      source = source_fixture()
      update_attrs = %{name: "some updated name"}

      assert {:ok, %Source{}} = Sources.update_source(source, update_attrs)
    end

    test "updates with invalid data returns error changeset" do
      source = source_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Sources.update_source(source, @invalid_source_attrs)

      assert source == Sources.get_source!(source.id)
    end

    test "updating will kickoff a metadata storage worker if the original_url changes" do
      expect(YtDlpRunnerMock, :run, &playlist_mock/5)
      source = source_fixture()
      update_attrs = %{original_url: "https://www.youtube.com/channel/cba321"}

      assert {:ok, %Source{} = source} = Sources.update_source(source, update_attrs)

      assert_enqueued(worker: SourceMetadataStorageWorker, args: %{"id" => source.id})
    end

    test "updating will not kickoff a metadata storage worker other attrs change" do
      source = source_fixture()
      update_attrs = %{name: "some new name"}

      assert {:ok, %Source{}} = Sources.update_source(source, update_attrs)

      refute_enqueued(worker: SourceMetadataStorageWorker)
    end
  end

  describe "update_source/3 when testing media download tasks" do
    test "enabling the download_media attribute will schedule a download task" do
      source = source_fixture(download_media: false)
      media_item = media_item_fixture(source_id: source.id, media_filepath: nil)
      update_attrs = %{download_media: true}

      refute_enqueued(worker: MediaDownloadWorker)
      assert {:ok, %Source{}} = Sources.update_source(source, update_attrs)
      assert_enqueued(worker: MediaDownloadWorker, args: %{"id" => media_item.id})
    end

    test "disabling the download_media attribute will cancel the download task" do
      source = source_fixture(download_media: true, enabled: true)
      media_item = media_item_fixture(source_id: source.id, media_filepath: nil)
      update_attrs = %{download_media: false}
      DownloadingHelpers.enqueue_pending_download_tasks(source)

      assert_enqueued(worker: MediaDownloadWorker, args: %{"id" => media_item.id})
      assert {:ok, %Source{}} = Sources.update_source(source, update_attrs)
      refute_enqueued(worker: MediaDownloadWorker)
    end

    test "enabling download_media will not schedule a task if the source is disabled" do
      source = source_fixture(download_media: false, enabled: false)
      _media_item = media_item_fixture(source_id: source.id, media_filepath: nil)
      update_attrs = %{download_media: true}

      refute_enqueued(worker: MediaDownloadWorker)
      assert {:ok, %Source{}} = Sources.update_source(source, update_attrs)
      refute_enqueued(worker: MediaDownloadWorker)
    end

    test "disabling a source will cancel any pending download tasks" do
      source = source_fixture(download_media: true, enabled: true)
      media_item = media_item_fixture(source_id: source.id, media_filepath: nil)
      update_attrs = %{enabled: false}
      DownloadingHelpers.enqueue_pending_download_tasks(source)

      assert_enqueued(worker: MediaDownloadWorker, args: %{"id" => media_item.id})
      assert {:ok, %Source{}} = Sources.update_source(source, update_attrs)
      refute_enqueued(worker: MediaDownloadWorker)
    end

    test "enabling a source will schedule a download task if download_media is true" do
      source = source_fixture(download_media: true, enabled: false)
      media_item = media_item_fixture(source_id: source.id, media_filepath: nil)
      update_attrs = %{enabled: true}

      refute_enqueued(worker: MediaDownloadWorker)
      assert {:ok, %Source{}} = Sources.update_source(source, update_attrs)
      assert_enqueued(worker: MediaDownloadWorker, args: %{"id" => media_item.id})
    end

    test "enabling a source will not schedule a download task if download_media is false" do
      source = source_fixture(download_media: false, enabled: false)
      _media_item = media_item_fixture(source_id: source.id, media_filepath: nil)
      update_attrs = %{enabled: true}

      refute_enqueued(worker: MediaDownloadWorker)
      assert {:ok, %Source{}} = Sources.update_source(source, update_attrs)
      refute_enqueued(worker: MediaDownloadWorker)
    end
  end

  describe "update_source/3 when testing slow indexing" do
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
      {:ok, job_2} = Oban.insert(MediaCollectionIndexingWorker.new(%{"id" => source.id}))
      task_2 = task_fixture(source_id: source.id, job_id: job_2.id)

      assert {:ok, %Source{}} = Sources.update_source(source, update_attrs)

      assert_raise Ecto.NoResultsError, fn -> Repo.reload!(task_1) end
      assert_raise Ecto.NoResultsError, fn -> Repo.reload!(task_2) end
    end

    test "not updating the index frequency will not re-schedule the indexing task or delete tasks" do
      source = source_fixture()
      task = task_fixture(source_id: source.id)
      update_attrs = %{name: "some updated name"}

      assert {:ok, %Source{}} = Sources.update_source(source, update_attrs)

      assert Repo.reload!(task)
      refute_enqueued(worker: MediaCollectionIndexingWorker, args: %{"id" => source.id})
    end

    test "disabling a source will delete any pending tasks" do
      source = source_fixture()
      update_attrs = %{enabled: false}

      {:ok, job} = Oban.insert(MediaCollectionIndexingWorker.new(%{"id" => source.id}))
      task = task_fixture(source_id: source.id, job_id: job.id)

      assert {:ok, %Source{}} = Sources.update_source(source, update_attrs)

      assert_raise Ecto.NoResultsError, fn -> Repo.reload!(task) end
    end

    test "updating the index frequency will not create a task if the source is disabled" do
      source = source_fixture(enabled: false)
      update_attrs = %{index_frequency_minutes: 123}

      refute_enqueued(worker: MediaCollectionIndexingWorker)
      assert {:ok, %Source{}} = Sources.update_source(source, update_attrs)
      refute_enqueued(worker: MediaCollectionIndexingWorker)
    end

    test "enabling a source will create a task if the index frequency is >0" do
      source = source_fixture(enabled: false, index_frequency_minutes: 123)
      update_attrs = %{enabled: true}

      refute_enqueued(worker: MediaCollectionIndexingWorker)
      assert {:ok, %Source{}} = Sources.update_source(source, update_attrs)
      assert_enqueued(worker: MediaCollectionIndexingWorker, args: %{"id" => source.id})
    end

    test "enabling a source will not create a task if the index frequency is 0" do
      source = source_fixture(enabled: false, index_frequency_minutes: 0)
      update_attrs = %{enabled: true}

      refute_enqueued(worker: MediaCollectionIndexingWorker)
      assert {:ok, %Source{}} = Sources.update_source(source, update_attrs)
      refute_enqueued(worker: MediaCollectionIndexingWorker)
    end
  end

  describe "update_source/3 when testing fast indexing" do
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

    test "disabling a source will delete any pending tasks" do
      source = source_fixture()
      update_attrs = %{enabled: false}

      {:ok, job} = Oban.insert(FastIndexingWorker.new(%{"id" => source.id}))
      task = task_fixture(source_id: source.id, job_id: job.id)

      assert {:ok, %Source{}} = Sources.update_source(source, update_attrs)

      assert_raise Ecto.NoResultsError, fn -> Repo.reload!(task) end
    end

    test "updating fast indexing will not create a task if the source is disabled" do
      source = source_fixture(enabled: false, fast_index: false)
      update_attrs = %{fast_index: true}

      refute_enqueued(worker: FastIndexingWorker)
      assert {:ok, %Source{}} = Sources.update_source(source, update_attrs)
      refute_enqueued(worker: FastIndexingWorker)
    end

    test "enabling a source will create a task if fast_index is true" do
      source = source_fixture(enabled: false, fast_index: true)
      update_attrs = %{enabled: true}

      refute_enqueued(worker: FastIndexingWorker)
      assert {:ok, %Source{}} = Sources.update_source(source, update_attrs)
      assert_enqueued(worker: FastIndexingWorker, args: %{"id" => source.id})
    end

    test "enabling a source will not create a task if fast_index is false" do
      source = source_fixture(enabled: false, fast_index: false)
      update_attrs = %{enabled: true}

      refute_enqueued(worker: FastIndexingWorker)
      assert {:ok, %Source{}} = Sources.update_source(source, update_attrs)
      refute_enqueued(worker: FastIndexingWorker)
    end
  end

  describe "update_source/3 when testing options" do
    test "run_post_commit_tasks: false won't enqueue post-commit tasks" do
      source = source_fixture(%{fast_index: false, download_media: false, index_frequency_minutes: -1})
      update_attrs = %{fast_index: true, download_media: true, index_frequency_minutes: 100}

      assert {:ok, %Source{}} = Sources.update_source(source, update_attrs, run_post_commit_tasks: false)

      refute_enqueued(worker: MediaCollectionIndexingWorker)
      refute_enqueued(worker: SourceMetadataStorageWorker)
      refute_enqueued(worker: MediaDownloadWorker)
      refute_enqueued(worker: FastIndexingWorker)
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

      assert {:ok, _} = Sources.delete_source(updated_source)
      refute File.exists?(updated_source.metadata.metadata_filepath)
    end

    test "does not delete the source's non-metadata files" do
      filepath = FilesystemUtils.generate_metadata_tmpfile(:nfo)
      source = source_fixture(%{nfo_filepath: filepath})

      assert {:ok, _} = Sources.delete_source(source)
      assert File.exists?(filepath)

      File.rm!(filepath)
    end
  end

  describe "delete_source/2 when deleting files" do
    setup do
      stub(UserScriptRunnerMock, :run, fn _event_type, _data -> {:ok, "", 0} end)

      :ok
    end

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

    test "deletes the source's non-metadata files" do
      filepath = FilesystemUtils.generate_metadata_tmpfile(:nfo)
      source = source_fixture(%{nfo_filepath: filepath})

      assert {:ok, _} = Sources.delete_source(source, delete_files: true)

      refute File.exists?(filepath)
    end
  end

  describe "change_source/3" do
    test "it returns a changeset" do
      source = source_fixture()

      assert %Ecto.Changeset{} = Sources.change_source(source)
    end
  end

  describe "change_source/3 when testing regex validation" do
    test "succeeds when a valid regex is provided" do
      source = source_fixture()

      assert %{errors: []} = Sources.change_source(source, %{title_filter_regex: "(?i)^How to Bike$"})
    end

    test "succeeds when a regex is set back to nil" do
      source = source_fixture(%{title_filter_regex: "(?i)^How to Bike$"})

      assert %{errors: []} = Sources.change_source(source, %{title_filter_regex: nil})
    end

    test "fails when an invalid regex is provided" do
      source = source_fixture()

      changeset = Sources.change_source(source, %{title_filter_regex: "*FOO"})

      assert "is invalid" in errors_on(changeset).title_filter_regex
    end
  end

  describe "change_source/3 when testing min/max duration validations" do
    test "succeeds if min and max are nil" do
      source = source_fixture()

      assert %{errors: []} = Sources.change_source(source, %{min_duration_seconds: nil, max_duration_seconds: nil})
    end

    test "succeeds if either min or max is nil" do
      source = source_fixture()

      assert %{errors: []} = Sources.change_source(source, %{min_duration_seconds: nil, max_duration_seconds: 100})
      assert %{errors: []} = Sources.change_source(source, %{min_duration_seconds: 100, max_duration_seconds: nil})
    end

    test "succeeds if min is less than max" do
      source = source_fixture()

      assert %{errors: []} = Sources.change_source(source, %{min_duration_seconds: 100, max_duration_seconds: 200})
    end

    test "fails if min is greater than or equal to max" do
      source = source_fixture()

      assert %{errors: [_]} = Sources.change_source(source, %{min_duration_seconds: 200, max_duration_seconds: 100})
      assert %{errors: [_]} = Sources.change_source(source, %{min_duration_seconds: 100, max_duration_seconds: 100})
    end
  end

  describe "change_source/3 when testing original_url validation" do
    test "succeeds when an original URL is valid" do
      source = source_fixture()

      valid_urls = [
        "https://www.youtube.com/channel/UCkRfArvrzheW2E7b6SVT7vQ",
        "https://www.youtube.com/channel/UCkRfArvrzheW2E7b6SVT7vQ/videos",
        "https://www.youtube.com/@youtubecreators/featured",
        "https://www.youtube.com/@youtubecreators",
        "https://www.youtube.com/c/YouTubeCreators",
        "https://www.youtube.com/user/YouTubeCreators",
        "https://www.youtube.com/YouTubeCreators",
        "https://www.youtube.com/playlist?list=PLpjK416fmKwRtq-9-O_NbZlkW0k6zu2Wn",
        "https://www.youtube.com/playlist?list=UUkRfArvrzheW2E7b6SVT7vQ"
      ]

      Enum.each(valid_urls, fn url ->
        assert %{errors: []} = Sources.change_source(source, %{original_url: url})
      end)
    end

    test "fails when an original URL points to a video" do
      source = source_fixture()

      invalid_urls = [
        "https://www.youtube.com/watch?v=72maj9FLQZI",
        "https://youtu.be/72maj9FLQZI",
        "https://www.youtube.com/watch?v=1FwGFhMAmBo&list=PLpjK416fmKwRtq-9-O_NbZlkW0k6zu2Wn",
        "https://www.youtube.com/shorts/Dq0eH-ZhQTU",
        "https://www.youtube.com/embed/X64LHlfx4qg"
      ]

      Enum.each(invalid_urls, fn url ->
        assert %{errors: [_]} = Sources.change_source(source, %{original_url: url})
      end)
    end

    test "passes when a non-youtube link is provided" do
      source = source_fixture()

      valid_urls = [
        "https://www.example.com",
        "https://www.example.com/playlist",
        "https://www.example.com/channel",
        "https://www.example.com/user",
        "https://www.example.com/watch?v=72maj9FLQZI",
        "https://www.example.com/embed/X64LHlfx4qg"
      ]

      Enum.each(valid_urls, fn url ->
        assert %{errors: []} = Sources.change_source(source, %{original_url: url})
      end)
    end
  end

  defp playlist_mock(_url, :get_source_details, _opts, _ot, _addl) do
    {:ok, playlist_return()}
  end

  defp channel_mock(_url, :get_source_details, _opts, _ot, _addl) do
    {:ok, channel_return()}
  end

  defp playlist_return do
    Phoenix.json_library().encode!(%{
      channel: nil,
      channel_id: nil,
      playlist_id: "some_playlist_id_#{:rand.uniform(1_000_000)}",
      playlist_title: "some playlist name"
    })
  end

  defp channel_return do
    channel_id = "some_channel_id_#{:rand.uniform(1_000_000)}"

    Phoenix.json_library().encode!(%{
      channel: "some channel name",
      channel_id: channel_id,
      playlist_id: channel_id,
      playlist_title: "some channel name - videos"
    })
  end
end
