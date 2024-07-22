defmodule PinchflatWeb.SourceControllerTest do
  use PinchflatWeb.ConnCase

  import Pinchflat.MediaFixtures
  import Pinchflat.SourcesFixtures
  import Pinchflat.ProfilesFixtures

  alias Pinchflat.Repo
  alias Pinchflat.Settings
  alias Pinchflat.Sources.SourceDeletionWorker
  alias Pinchflat.Downloading.MediaDownloadWorker
  alias Pinchflat.Metadata.SourceMetadataStorageWorker
  alias Pinchflat.SlowIndexing.MediaCollectionIndexingWorker

  setup do
    media_profile = media_profile_fixture()
    Settings.set(onboarding: false)

    {
      :ok,
      %{
        create_attrs: %{
          media_profile_id: media_profile.id,
          collection_type: "channel",
          original_url: "https://www.youtube.com/source/abc123"
        },
        update_attrs: %{
          original_url: "https://www.youtube.com/source/321xyz"
        },
        invalid_attrs: %{original_url: nil, media_profile_id: nil}
      }
    }
  end

  describe "index" do
    test "lists all sources", %{conn: conn} do
      source = source_fixture()
      conn = get(conn, ~p"/sources")

      assert html_response(conn, 200) =~ "Sources"
      assert html_response(conn, 200) =~ source.custom_name
    end

    test "omits sources that have marked_for_deletion_at set", %{conn: conn} do
      source = source_fixture(marked_for_deletion_at: DateTime.utc_now())
      conn = get(conn, ~p"/sources")

      refute html_response(conn, 200) =~ source.custom_name
    end

    test "omits sources who's media profile has marked_for_deletion_at set", %{conn: conn} do
      media_profile = media_profile_fixture(marked_for_deletion_at: DateTime.utc_now())
      source = source_fixture(media_profile_id: media_profile.id)
      conn = get(conn, ~p"/sources")

      refute html_response(conn, 200) =~ source.custom_name
    end
  end

  describe "new source" do
    test "renders form", %{conn: conn} do
      conn = get(conn, ~p"/sources/new")
      assert html_response(conn, 200) =~ "New Source"
    end

    test "renders correct layout when onboarding", %{conn: conn} do
      Settings.set(onboarding: true)
      conn = get(conn, ~p"/sources/new")

      refute html_response(conn, 200) =~ "MENU"
    end

    test "preloads some attributes when using a template", %{conn: conn} do
      source = source_fixture(custom_name: "My first source", download_cutoff_date: "2021-01-01")

      conn = get(conn, ~p"/sources/new", %{"template_id" => source.id})
      assert html_response(conn, 200) =~ "New Source"
      assert html_response(conn, 200) =~ "2021-01-01"
      refute html_response(conn, 200) =~ source.custom_name
    end
  end

  describe "create source" do
    test "redirects to show when data is valid", %{conn: conn, create_attrs: create_attrs} do
      expect(YtDlpRunnerMock, :run, 1, &runner_function_mock/3)
      conn = post(conn, ~p"/sources", source: create_attrs)

      assert %{id: id} = redirected_params(conn)
      assert redirected_to(conn) == ~p"/sources/#{id}"

      conn = get(conn, ~p"/sources/#{id}")
      assert html_response(conn, 200) =~ "Source"
    end

    test "renders errors when data is invalid", %{conn: conn, invalid_attrs: invalid_attrs} do
      conn = post(conn, ~p"/sources", source: invalid_attrs)
      assert html_response(conn, 200) =~ "New Source"
    end

    test "redirects to onboarding when onboarding", %{conn: conn, create_attrs: create_attrs} do
      expect(YtDlpRunnerMock, :run, 1, &runner_function_mock/3)

      Settings.set(onboarding: true)
      conn = post(conn, ~p"/sources", source: create_attrs)

      assert redirected_to(conn) == ~p"/?onboarding=1"
    end

    test "renders correct layout on error when onboarding", %{conn: conn, invalid_attrs: invalid_attrs} do
      Settings.set(onboarding: true)
      conn = post(conn, ~p"/sources", source: invalid_attrs)

      refute html_response(conn, 200) =~ "MENU"
    end
  end

  describe "edit source" do
    setup [:create_source]

    test "renders form for editing chosen source", %{conn: conn, source: source} do
      conn = get(conn, ~p"/sources/#{source}/edit")
      assert html_response(conn, 200) =~ "Editing \"#{source.custom_name}\""
    end
  end

  describe "update source" do
    setup [:create_source]

    test "redirects when data is valid", %{conn: conn, source: source, update_attrs: update_attrs} do
      expect(YtDlpRunnerMock, :run, 1, &runner_function_mock/3)

      conn = put(conn, ~p"/sources/#{source}", source: update_attrs)
      assert redirected_to(conn) == ~p"/sources/#{source}"

      conn = get(conn, ~p"/sources/#{source}")
      assert html_response(conn, 200) =~ "https://www.youtube.com/source/321xyz"
    end

    test "renders errors when data is invalid", %{
      conn: conn,
      source: source,
      invalid_attrs: invalid_attrs
    } do
      conn = put(conn, ~p"/sources/#{source}", source: invalid_attrs)
      assert html_response(conn, 200) =~ "Editing \"#{source.custom_name}\""
    end
  end

  describe "delete source in all cases" do
    setup [:create_source]

    test "redirects to the sources page", %{conn: conn, source: source} do
      conn = delete(conn, ~p"/sources/#{source}")
      assert redirected_to(conn) == ~p"/sources"
    end

    test "sets marked_for_deletion_at", %{conn: conn, source: source} do
      delete(conn, ~p"/sources/#{source}")
      assert Repo.reload!(source).marked_for_deletion_at
    end
  end

  describe "delete source when just deleting the records" do
    setup [:create_source]

    test "enqueues a job without the delete_files arg", %{conn: conn, source: source} do
      delete(conn, ~p"/sources/#{source}")

      assert [%{args: %{"delete_files" => false}}] = all_enqueued(worker: SourceDeletionWorker)
    end
  end

  describe "delete source when deleting the records and files" do
    setup [:create_source]

    test "enqueues a job without the delete_files arg", %{conn: conn, source: source} do
      delete(conn, ~p"/sources/#{source}?delete_files=true")

      assert [%{args: %{"delete_files" => true}}] = all_enqueued(worker: SourceDeletionWorker)
    end
  end

  describe "force_download_pending" do
    test "enqueues pending download tasks", %{conn: conn} do
      source = source_fixture()
      _media_item = media_item_fixture(%{source_id: source.id, media_filepath: nil})

      assert [] = all_enqueued(worker: MediaDownloadWorker)
      post(conn, ~p"/sources/#{source.id}/force_download_pending")
      assert [_] = all_enqueued(worker: MediaDownloadWorker)
    end

    test "redirects to the source page", %{conn: conn} do
      source = source_fixture()

      conn = post(conn, ~p"/sources/#{source.id}/force_download_pending")
      assert redirected_to(conn) == ~p"/sources/#{source.id}"
    end
  end

  describe "force_redownload" do
    test "enqueues re-download tasks", %{conn: conn} do
      source = source_fixture()
      _media_item = media_item_fixture(source_id: source.id, media_downloaded_at: now())

      assert [] = all_enqueued(worker: MediaDownloadWorker)
      post(conn, ~p"/sources/#{source.id}/force_redownload")
      assert [_] = all_enqueued(worker: MediaDownloadWorker)
    end

    test "redirects to the source page", %{conn: conn} do
      source = source_fixture()

      conn = post(conn, ~p"/sources/#{source.id}/force_redownload")
      assert redirected_to(conn) == ~p"/sources/#{source.id}"
    end
  end

  describe "force_index" do
    test "forces an index", %{conn: conn} do
      source = source_fixture()

      assert [] = all_enqueued(worker: MediaCollectionIndexingWorker)
      post(conn, ~p"/sources/#{source.id}/force_index")
      assert [_] = all_enqueued(worker: MediaCollectionIndexingWorker)
    end

    test "forces an index even if one wouldn't normally run", %{conn: conn} do
      source = source_fixture(index_frequency_minutes: 0, last_indexed_at: DateTime.utc_now())

      post(conn, ~p"/sources/#{source.id}/force_index")
      assert [job] = all_enqueued(worker: MediaCollectionIndexingWorker)
      assert job.args == %{"id" => source.id, "force" => true}
    end

    test "deletes pending indexing tasks", %{conn: conn} do
      source = source_fixture()
      {:ok, task} = MediaCollectionIndexingWorker.kickoff_with_task(source)
      job = Repo.preload(task, :job).job

      assert job.state == "available"
      post(conn, ~p"/sources/#{source.id}/force_index")
      assert Repo.reload!(job).state == "cancelled"
    end

    test "redirects to the source page", %{conn: conn} do
      source = source_fixture()

      conn = post(conn, ~p"/sources/#{source.id}/force_index")
      assert redirected_to(conn) == ~p"/sources/#{source.id}"
    end
  end

  describe "force_metadata_refresh" do
    test "forces a metadata refresh", %{conn: conn} do
      source = source_fixture()

      assert [] = all_enqueued(worker: SourceMetadataStorageWorker)
      post(conn, ~p"/sources/#{source.id}/force_metadata_refresh")
      assert [_] = all_enqueued(worker: SourceMetadataStorageWorker)
    end

    test "redirects to the source page", %{conn: conn} do
      source = source_fixture()

      conn = post(conn, ~p"/sources/#{source.id}/force_metadata_refresh")
      assert redirected_to(conn) == ~p"/sources/#{source.id}"
    end
  end

  defp create_source(_) do
    source = source_fixture()
    media_item = media_item_with_attachments(%{source_id: source.id})

    %{source: source, media_item: media_item}
  end

  defp runner_function_mock(_url, _opts, _ot) do
    {
      :ok,
      Phoenix.json_library().encode!(%{
        channel: "some channel name",
        channel_id: "some_channel_id_#{:rand.uniform(1_000_000)}",
        playlist_id: "some_playlist_id_#{:rand.uniform(1_000_000)}",
        playlist_title: "some playlist name"
      })
    }
  end
end
