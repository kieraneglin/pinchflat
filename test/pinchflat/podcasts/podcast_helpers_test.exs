defmodule Pinchflat.Podcasts.PodcastHelpersTest do
  use Pinchflat.DataCase

  import Pinchflat.SourcesFixtures
  import Pinchflat.MediaFixtures

  alias Pinchflat.Podcasts.PodcastHelpers

  describe "persisted_media_items_for/2" do
    test "returns media items with files that exist on-disk" do
      source = source_fixture()
      good_media = media_item_with_attachments(%{source_id: source.id})
      _bad_media = media_item_fixture(%{source_id: source.id, media_filepath: "/tmp/existing_file.mp3"})

      assert [persisted_media] = PodcastHelpers.persisted_media_items_for(source)
      assert persisted_media.id == good_media.id
    end

    test "lets you specify a limit" do
      source = source_fixture()
      _good_media = media_item_with_attachments(%{source_id: source.id})

      assert [] = PodcastHelpers.persisted_media_items_for(source, limit: 0)
    end

    test "orders by upload date where newest is first" do
      source = source_fixture()

      oldest = media_item_with_attachments(%{source_id: source.id, upload_date: now_minus(2, :day)})
      current = media_item_with_attachments(%{source_id: source.id, upload_date: now()})
      older = media_item_with_attachments(%{source_id: source.id, upload_date: now_minus(1, :days)})

      assert [^current, ^older, ^oldest] = PodcastHelpers.persisted_media_items_for(source)
    end
  end

  describe "select_cover_image/2" do
    test "returns a source's poster, if present" do
      source = source_with_metadata_attachments()

      {:ok, res} = PodcastHelpers.select_cover_image(source, [])

      assert res == source.metadata.poster_filepath
    end

    test "falls back to a source's fanart, if present" do
      source = source_with_metadata_attachments()

      File.rm(source.metadata.poster_filepath)

      {:ok, res} = PodcastHelpers.select_cover_image(source, [])

      assert res == source.metadata.fanart_filepath
    end

    test "falls back to a media item's thumbnail, if present" do
      source = source_with_metadata_attachments()
      media_item = media_item_with_metadata_attachments(%{source_id: source.id})

      File.rm(source.metadata.poster_filepath)
      File.rm(source.metadata.fanart_filepath)

      {:ok, res} = PodcastHelpers.select_cover_image(source, [media_item])

      assert res == media_item.metadata.thumbnail_filepath
    end

    test "returns error if no artwork can be found" do
      source = source_fixture()

      assert PodcastHelpers.select_cover_image(source, []) == {:error, :no_suitable_image}
    end
  end
end
