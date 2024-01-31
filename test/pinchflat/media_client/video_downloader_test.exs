defmodule Pinchflat.MediaClient.VideoDownloaderTest do
  use Pinchflat.DataCase
  import Mox
  import Pinchflat.MediaFixtures

  alias Pinchflat.MediaClient.VideoDownloader

  setup :verify_on_exit!

  setup do
    media_item =
      Repo.preload(
        media_item_fixture(%{title: nil, video_filepath: nil}),
        [:metadata, channel: :media_profile]
      )

    {:ok, %{media_item: media_item}}
  end

  describe "download_for_media_item/3" do
    test "it calls the backend runner", %{media_item: media_item} do
      expect(YtDlpRunnerMock, :run, fn _url, _opts, ot ->
        assert ot == "after_move:%()j"

        {:ok, render_metadata(:media_metadata)}
      end)

      assert {:ok, _} = VideoDownloader.download_for_media_item(media_item)
    end

    test "it writes attributes to the media item", %{media_item: media_item} do
      expect(YtDlpRunnerMock, :run, fn _url, _opts, _ot ->
        {:ok, render_metadata(:media_metadata)}
      end)

      assert %{video_filepath: nil, title: nil} = media_item
      assert {:ok, updated_media_item} = VideoDownloader.download_for_media_item(media_item)
      assert updated_media_item.video_filepath
      assert updated_media_item.title
    end

    test "it saves the metadata to the database", %{media_item: media_item} do
      expect(YtDlpRunnerMock, :run, fn _url, _opts, _ot ->
        {:ok, render_metadata(:media_metadata)}
      end)

      assert is_nil(media_item.metadata)
      assert {:ok, updated_media_item} = VideoDownloader.download_for_media_item(media_item)
      assert updated_media_item.metadata
      assert is_map(updated_media_item.metadata.client_response)
    end

    test "errors are passed through", %{media_item: media_item} do
      expect(YtDlpRunnerMock, :run, fn _url, _opts, _ot ->
        {:error, :some_error}
      end)

      assert {:error, :some_error} = VideoDownloader.download_for_media_item(media_item)
    end
  end
end
