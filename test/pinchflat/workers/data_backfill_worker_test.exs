defmodule Pinchflat.Workers.DataBackfillWorkerTest do
  use Pinchflat.DataCase

  import Pinchflat.MediaFixtures

  alias Pinchflat.Workers.DataBackfillWorker

  describe "perform/1" do
    test "reschedules itself once complete" do
      perform_job(DataBackfillWorker, %{})

      assert_enqueued(worker: DataBackfillWorker, scheduled_at: now_plus(60, :minutes))
    end
  end

  describe "perform/1 when testing backfill_shorts_data" do
    test "sets short_form_content to true for media items with shorts in the URL" do
      media_item = media_item_with_attachments(%{original_url: "https://example.com/shorts/123"})

      refute media_item.short_form_content

      perform_job(DataBackfillWorker, %{})

      assert Repo.reload!(media_item).short_form_content
    end

    test "does not set short_form_content to true for media items without shorts in the URL" do
      media_item = media_item_with_attachments(%{original_url: "https://example.com/longs/123"})

      refute media_item.short_form_content

      perform_job(DataBackfillWorker, %{})

      refute Repo.reload!(media_item).short_form_content
    end
  end
end
