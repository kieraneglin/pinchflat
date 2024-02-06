defmodule Pinchflat.MediaClient.VideoDownloaderTest do
  use Pinchflat.DataCase
  import Mox
  import Pinchflat.MediaFixtures

  alias Pinchflat.MediaClient.VideoDownloader

  setup :verify_on_exit!

  setup do
    media_item =
      Repo.preload(
        media_item_fixture(%{title: nil, media_filepath: nil}),
        [:metadata, source: :media_profile]
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

  describe "download_for_media_item/3 when testing media_item attributes" do
    setup do
      expect(YtDlpRunnerMock, :run, fn _url, _opts, _ot ->
        {:ok, render_metadata(:media_metadata)}
      end)

      :ok
    end

    test "it extracts the title", %{media_item: media_item} do
      assert media_item.title == nil
      assert {:ok, updated_media_item} = VideoDownloader.download_for_media_item(media_item)
      assert updated_media_item.title == "Trying to Wheelie Without the Rear Brake"
    end

    test "it extracts the media_filepath", %{media_item: media_item} do
      assert media_item.media_filepath == nil
      assert {:ok, updated_media_item} = VideoDownloader.download_for_media_item(media_item)
      assert String.ends_with?(updated_media_item.media_filepath, ".mkv")
    end

    test "it extracts the subtitle_filepaths", %{media_item: media_item} do
      assert media_item.subtitle_filepaths == []
      assert {:ok, updated_media_item} = VideoDownloader.download_for_media_item(media_item)
      assert [["de", _], ["en", _] | _rest] = updated_media_item.subtitle_filepaths
    end

    test "it extracts the thumbnail_filepath", %{media_item: media_item} do
      assert media_item.thumbnail_filepath == nil
      assert {:ok, updated_media_item} = VideoDownloader.download_for_media_item(media_item)
      assert String.ends_with?(updated_media_item.thumbnail_filepath, ".webp")
    end

    test "it extracts the metadata_filepath", %{media_item: media_item} do
      assert media_item.metadata_filepath == nil
      assert {:ok, updated_media_item} = VideoDownloader.download_for_media_item(media_item)
      assert String.ends_with?(updated_media_item.metadata_filepath, ".info.json")
    end
  end
end
