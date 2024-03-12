defmodule Pinchflat.FastIndexing.FastIndexingWorkerTest do
  use Pinchflat.DataCase

  import Mox
  import Pinchflat.SourcesFixtures

  alias Pinchflat.Sources.Source
  alias Pinchflat.FastIndexing.FastIndexingWorker

  setup :verify_on_exit!

  describe "perform/1" do
    test "calls out to Youtube RSS if enabled" do
      expect(HTTPClientMock, :get, fn _url -> {:ok, ""} end)
      source = source_fixture(fast_index: true)

      perform_job(FastIndexingWorker, %{"id" => source.id})
    end

    test "reschedules itself if fast indexing is enabled" do
      expect(HTTPClientMock, :get, fn _url -> {:ok, ""} end)
      source = source_fixture(fast_index: true)
      perform_job(FastIndexingWorker, %{"id" => source.id})

      assert_enqueued(
        worker: FastIndexingWorker,
        args: %{"id" => source.id},
        scheduled_at: now_plus(Source.fast_index_frequency(), :minutes)
      )
    end

    test "does not call out to Youtube RSS if disabled" do
      expect(HTTPClientMock, :get, 0, fn _url -> {:ok, ""} end)
      source = source_fixture(fast_index: false)

      perform_job(FastIndexingWorker, %{"id" => source.id})
    end

    test "does not reschedule itself if fast indexing is disabled" do
      source = source_fixture(fast_index: false)
      perform_job(FastIndexingWorker, %{"id" => source.id})

      refute_enqueued(worker: FastIndexingWorker, args: %{"id" => source.id})
    end
  end
end
