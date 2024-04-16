defmodule Pinchflat.FastIndexing.FastIndexingWorkerTest do
  use Pinchflat.DataCase

  import Mox
  import Pinchflat.SourcesFixtures

  alias Pinchflat.Settings
  alias Pinchflat.Sources.Source
  alias Pinchflat.FastIndexing.FastIndexingWorker

  setup :verify_on_exit!

  describe "kickoff_with_task/2" do
    test "starts the worker" do
      source = source_fixture(fast_index: true)

      assert [] = all_enqueued(worker: FastIndexingWorker)
      assert {:ok, _} = FastIndexingWorker.kickoff_with_task(source)
      assert [_] = all_enqueued(worker: FastIndexingWorker)
    end

    test "attaches a task" do
      source = source_fixture(fast_index: true)

      assert {:ok, task} = FastIndexingWorker.kickoff_with_task(source)
      assert task.source_id == source.id
    end
  end

  describe "perform/1" do
    test "calls out to Youtube RSS if enabled" do
      expect(HTTPClientMock, :get, fn _url -> {:ok, ""} end)
      source = source_fixture(fast_index: true)

      perform_job(FastIndexingWorker, %{id: source.id})
    end

    test "reschedules itself if fast indexing is enabled" do
      expect(HTTPClientMock, :get, fn _url -> {:ok, ""} end)
      source = source_fixture(fast_index: true)
      perform_job(FastIndexingWorker, %{id: source.id})

      assert_enqueued(
        worker: FastIndexingWorker,
        args: %{"id" => source.id},
        scheduled_at: now_plus(Source.fast_index_frequency(), :minutes)
      )
    end

    test "does not reschedule if that would create a duplicate job" do
      stub(HTTPClientMock, :get, fn _url -> {:ok, ""} end)
      source = source_fixture(fast_index: true)

      perform_job(FastIndexingWorker, %{id: source.id})
      perform_job(FastIndexingWorker, %{id: source.id})

      assert [_] = all_enqueued(worker: FastIndexingWorker)
    end

    test "does not call out to Youtube RSS if disabled" do
      expect(HTTPClientMock, :get, 0, fn _url -> {:ok, ""} end)
      source = source_fixture(fast_index: false)

      perform_job(FastIndexingWorker, %{id: source.id})
    end

    test "does not reschedule itself if fast indexing is disabled" do
      source = source_fixture(fast_index: false)
      perform_job(FastIndexingWorker, %{id: source.id})

      refute_enqueued(worker: FastIndexingWorker, args: %{"id" => source.id})
    end

    test "does not blow up if the record doesn't exist" do
      assert :ok = perform_job(FastIndexingWorker, %{id: 0})
    end
  end

  describe "perform/1 when testing notifications" do
    setup do
      Settings.set(apprise_server: "server_1")

      :ok
    end

    test "sends a notification if new media was found" do
      source = source_fixture(fast_index: true)

      expect(HTTPClientMock, :get, fn _url -> {:ok, "<yt:videoId>test_1</yt:videoId>"} end)
      expect(YtDlpRunnerMock, :run, fn _url, _opts, _ot -> {:ok, render_metadata(:media_metadata)} end)

      expect(AppriseRunnerMock, :run, fn servers, opts ->
        assert "server_1" = servers
        assert is_binary(Keyword.get(opts, :title))
        assert is_binary(Keyword.get(opts, :body))

        {:ok, ""}
      end)

      perform_job(FastIndexingWorker, %{id: source.id})
    end

    test "doesn't send a notification if new media is not found" do
      source = source_fixture(fast_index: true)

      expect(HTTPClientMock, :get, fn _url -> {:ok, ""} end)
      expect(AppriseRunnerMock, :run, 0, fn _servers, _opts -> {:ok, ""} end)

      perform_job(FastIndexingWorker, %{id: source.id})
    end

    test "doesn't send a notification if the source doesn't download media" do
      source = source_fixture(fast_index: true, download_media: false)

      expect(HTTPClientMock, :get, fn _url -> {:ok, "<yt:videoId>test_1</yt:videoId>"} end)
      expect(YtDlpRunnerMock, :run, fn _url, _opts, _ot -> {:ok, render_metadata(:media_metadata)} end)
      expect(AppriseRunnerMock, :run, 0, fn _servers, _opts -> {:ok, ""} end)

      perform_job(FastIndexingWorker, %{id: source.id})
    end

    test "doesn't send a notification if the media isn't pending download" do
      source = source_fixture(fast_index: true, title_filter_regex: "foobar")

      expect(HTTPClientMock, :get, fn _url -> {:ok, "<yt:videoId>test_1</yt:videoId>"} end)
      expect(YtDlpRunnerMock, :run, fn _url, _opts, _ot -> {:ok, render_metadata(:media_metadata)} end)
      expect(AppriseRunnerMock, :run, 0, fn _servers, _opts -> {:ok, ""} end)

      perform_job(FastIndexingWorker, %{id: source.id})
    end
  end
end
