defmodule Pinchflat.MediaTest do
  use Pinchflat.DataCase

  import Pinchflat.MediaFixtures
  import Pinchflat.MediaSourceFixtures

  alias Pinchflat.Media
  alias Pinchflat.Media.MediaItem

  @invalid_attrs %{title: nil, media_id: nil, video_filepath: nil}

  describe "list_media_items/0" do
    test "it returns all media_items" do
      media_item = media_item_fixture()
      assert Media.list_media_items() == [media_item]
    end
  end

  describe "get_media_item!/1" do
    test "it returns the media_item with given id" do
      media_item = media_item_fixture()
      assert Media.get_media_item!(media_item.id) == media_item
    end
  end

  describe "create_media_item/1" do
    test "creating with valid data creates a media_item" do
      valid_attrs = %{
        media_id: Faker.String.base64(12),
        title: Faker.Commerce.product_name(),
        video_filepath: "/video/#{Faker.File.file_name(:video)}",
        channel_id: channel_fixture().id
      }

      assert {:ok, %MediaItem{} = media_item} = Media.create_media_item(valid_attrs)
      assert media_item.title == valid_attrs.title
      assert media_item.media_id == valid_attrs.media_id
      assert media_item.video_filepath == valid_attrs.video_filepath
    end

    test "creating with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Media.create_media_item(@invalid_attrs)
    end
  end

  describe "update_media_item/2" do
    test "updating with valid data updates the media_item" do
      media_item = media_item_fixture()

      update_attrs = %{
        media_id: Faker.String.base64(12),
        title: Faker.Commerce.product_name(),
        video_filepath: "/video/#{Faker.File.file_name(:video)}",
        channel_id: channel_fixture().id
      }

      assert {:ok, %MediaItem{} = media_item} = Media.update_media_item(media_item, update_attrs)
      assert media_item.title == update_attrs.title
      assert media_item.media_id == update_attrs.media_id
      assert media_item.video_filepath == update_attrs.video_filepath
    end

    test "updating with invalid data returns error changeset" do
      media_item = media_item_fixture()
      assert {:error, %Ecto.Changeset{}} = Media.update_media_item(media_item, @invalid_attrs)
      assert media_item == Media.get_media_item!(media_item.id)
    end
  end

  describe "delete_media_item/1" do
    test "deletion deletes the media_item" do
      media_item = media_item_fixture()
      assert {:ok, %MediaItem{}} = Media.delete_media_item(media_item)
      assert_raise Ecto.NoResultsError, fn -> Media.get_media_item!(media_item.id) end
    end
  end

  describe "change_media_item/1" do
    test "change_media_item/1 returns a media_item changeset" do
      media_item = media_item_fixture()
      assert %Ecto.Changeset{} = Media.change_media_item(media_item)
    end
  end
end