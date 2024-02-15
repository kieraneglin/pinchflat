defmodule Pinchflat.MediaTest do
  use Pinchflat.DataCase

  import Pinchflat.TasksFixtures
  import Pinchflat.MediaFixtures
  import Pinchflat.ProfilesFixtures
  import Pinchflat.MediaSourceFixtures

  alias Pinchflat.Media
  alias Pinchflat.Media.MediaItem

  @invalid_attrs %{title: nil, media_id: nil, media_filepath: nil}

  describe "schema" do
    test "media_metadata is deleted when media_item is deleted" do
      media_item = media_item_fixture(%{metadata: %{client_response: %{foo: "bar"}}})
      metadata = media_item.metadata
      assert {:ok, %MediaItem{}} = Media.delete_media_item(media_item)

      assert_raise Ecto.NoResultsError, fn ->
        Repo.reload!(metadata)
      end
    end
  end

  describe "list_media_items/0" do
    test "it returns all media_items" do
      media_item = media_item_fixture()
      assert Media.list_media_items() == [media_item]
    end
  end

  describe "list_pending_media_items_for/1" do
    test "it returns pending without a filepath for a given source" do
      source = source_fixture()
      media_item = media_item_fixture(%{source_id: source.id, media_filepath: nil})

      assert Media.list_pending_media_items_for(source) == [media_item]
    end

    test "it does not return media_items with media_filepath" do
      source = source_fixture()

      _media_item =
        media_item_fixture(%{
          source_id: source.id,
          media_filepath: "/video/#{Faker.File.file_name(:video)}"
        })

      assert Media.list_pending_media_items_for(source) == []
    end
  end

  describe "list_pending_media_items_for/1 when testing shorts" do
    test "returns shorts and normal media when shorts_behaviour is :include" do
      source = source_fixture(%{media_profile_id: media_profile_fixture(%{shorts_behaviour: :include}).id})
      normal = media_item_fixture(%{source_id: source.id, media_filepath: nil})
      short = media_item_fixture(%{source_id: source.id, media_filepath: nil, original_url: "/shorts/"})

      assert Media.list_pending_media_items_for(source) == [normal, short]
    end

    test "returns only shorts when shorts_behaviour is :only" do
      source = source_fixture(%{media_profile_id: media_profile_fixture(%{shorts_behaviour: :only}).id})
      _normal = media_item_fixture(%{source_id: source.id, media_filepath: nil})
      short = media_item_fixture(%{source_id: source.id, media_filepath: nil, original_url: "/shorts/"})

      assert Media.list_pending_media_items_for(source) == [short]
    end

    test "returns only normal media when shorts_behaviour is :exclude" do
      source = source_fixture(%{media_profile_id: media_profile_fixture(%{shorts_behaviour: :exclude}).id})
      normal = media_item_fixture(%{source_id: source.id, media_filepath: nil})
      _short = media_item_fixture(%{source_id: source.id, media_filepath: nil, original_url: "/shorts/"})

      assert Media.list_pending_media_items_for(source) == [normal]
    end
  end

  describe "list_pending_media_items_for/1 when testing livestreams" do
    test "returns livestreams and normal media when livestream_behaviour is :include" do
      source = source_fixture(%{media_profile_id: media_profile_fixture(%{livestream_behaviour: :include}).id})
      normal = media_item_fixture(%{source_id: source.id, media_filepath: nil})
      livestream = media_item_fixture(%{source_id: source.id, media_filepath: nil, livestream: true})

      assert Media.list_pending_media_items_for(source) == [normal, livestream]
    end

    test "returns only livestreams when livestream_behaviour is :only" do
      source = source_fixture(%{media_profile_id: media_profile_fixture(%{livestream_behaviour: :only}).id})
      _normal = media_item_fixture(%{source_id: source.id, media_filepath: nil})
      livestream = media_item_fixture(%{source_id: source.id, media_filepath: nil, livestream: true})

      assert Media.list_pending_media_items_for(source) == [livestream]
    end

    test "returns only normal media when livestream_behaviour is :exclude" do
      source = source_fixture(%{media_profile_id: media_profile_fixture(%{livestream_behaviour: :exclude}).id})
      normal = media_item_fixture(%{source_id: source.id, media_filepath: nil})
      _livestream = media_item_fixture(%{source_id: source.id, media_filepath: nil, livestream: true})

      assert Media.list_pending_media_items_for(source) == [normal]
    end
  end

  describe "list_pending_media_items_for/1 when testing all format options" do
    test "returns livestreams, shorts, and normal media when behaviour is :include" do
      source =
        source_fixture(%{
          media_profile_id:
            media_profile_fixture(%{
              shorts_behaviour: :include,
              livestream_behaviour: :include
            }).id
        })

      normal = media_item_fixture(%{source_id: source.id, media_filepath: nil})
      livestream = media_item_fixture(%{source_id: source.id, media_filepath: nil, livestream: true})
      short = media_item_fixture(%{source_id: source.id, media_filepath: nil, original_url: "/shorts/"})

      assert Media.list_pending_media_items_for(source) == [normal, livestream, short]
    end

    test "returns only livestreams and shorts when behaviour is :only" do
      source =
        source_fixture(%{
          media_profile_id:
            media_profile_fixture(%{
              shorts_behaviour: :only,
              livestream_behaviour: :only
            }).id
        })

      _normal = media_item_fixture(%{source_id: source.id, media_filepath: nil})
      livestream = media_item_fixture(%{source_id: source.id, media_filepath: nil, livestream: true})
      short = media_item_fixture(%{source_id: source.id, media_filepath: nil, original_url: "/shorts/"})

      assert Media.list_pending_media_items_for(source) == [livestream, short]
    end

    test "returns only normal media when behaviour is :exclude" do
      source =
        source_fixture(%{
          media_profile_id:
            media_profile_fixture(%{
              shorts_behaviour: :exclude,
              livestream_behaviour: :exclude
            }).id
        })

      normal = media_item_fixture(%{source_id: source.id, media_filepath: nil})
      _livestream = media_item_fixture(%{source_id: source.id, media_filepath: nil, livestream: true})
      _short = media_item_fixture(%{source_id: source.id, media_filepath: nil, original_url: "/shorts/"})

      assert Media.list_pending_media_items_for(source) == [normal]
    end

    test ":only and :exclude return the expected results" do
      source =
        source_fixture(%{
          media_profile_id:
            media_profile_fixture(%{
              shorts_behaviour: :only,
              livestream_behaviour: :exclude
            }).id
        })

      _normal = media_item_fixture(%{source_id: source.id, media_filepath: nil})
      _livestream = media_item_fixture(%{source_id: source.id, media_filepath: nil, livestream: true})
      short = media_item_fixture(%{source_id: source.id, media_filepath: nil, original_url: "/shorts/"})

      assert Media.list_pending_media_items_for(source) == [short]
    end
  end

  describe "list_downloaded_media_items_for/1" do
    test "returns only media items with a media_filepath" do
      source = source_fixture()
      _media_item = media_item_fixture(%{source_id: source.id, media_filepath: nil})
      media_item = media_item_fixture(%{source_id: source.id, media_filepath: "/video/#{Faker.File.file_name(:video)}"})

      assert Media.list_downloaded_media_items_for(source) == [media_item]
    end
  end

  describe "search/1" do
    setup do
      media_item =
        media_item_fixture(%{
          title: "The quick brown fox",
          description: "jumps over the lazy dog"
        })

      {:ok, %{media_item_id: media_item.id}}
    end

    test "searches based on title", %{media_item_id: media_item_id} do
      assert [%{id: ^media_item_id}] = Media.search("quick")
    end

    test "searches based on description", %{media_item_id: media_item_id} do
      assert [%{id: ^media_item_id}] = Media.search("lazy")
    end

    test "adds a matching_search_term attribute with the relevant text" do
      assert [res] = Media.search("quick")
      assert String.contains?(res.matching_search_term, "The [PF_HIGHLIGHT]quick[/PF_HIGHLIGHT] brown fox")
    end

    test "optionally lets you specify a limit" do
      media_item_fixture(%{title: "The small gray dog"})

      assert [_] = Media.search("dog", limit: 1)
    end
  end

  describe "get_media_item!/1" do
    test "it returns the media_item with given id" do
      media_item = media_item_fixture()
      assert Media.get_media_item!(media_item.id) == media_item
    end
  end

  describe "media_filepaths/1" do
    test "returns filepaths in a flat list" do
      filepaths = %{
        media_filepath: "/video/test.mp4",
        thumbnail_filepath: "/video/test.jpg",
        subtitle_filepaths: [["en", "video/test.srt"]]
      }

      media_item = media_item_fixture(filepaths)

      assert Media.media_filepaths(media_item) == [
               "/video/test.mp4",
               "/video/test.jpg",
               "video/test.srt"
             ]
    end
  end

  describe "create_media_item/1" do
    test "creating with valid data creates a media_item" do
      valid_attrs = %{
        media_id: Faker.String.base64(12),
        title: Faker.Commerce.product_name(),
        media_filepath: "/video/#{Faker.File.file_name(:video)}",
        source_id: source_fixture().id,
        original_url: "https://www.youtube.com/channel/#{Faker.String.base64(12)}"
      }

      assert {:ok, %MediaItem{} = media_item} = Media.create_media_item(valid_attrs)
      assert media_item.title == valid_attrs.title
      assert media_item.media_id == valid_attrs.media_id
      assert media_item.media_filepath == valid_attrs.media_filepath
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
        media_filepath: "/video/#{Faker.File.file_name(:video)}",
        source_id: source_fixture().id
      }

      assert {:ok, %MediaItem{} = media_item} = Media.update_media_item(media_item, update_attrs)
      assert media_item.title == update_attrs.title
      assert media_item.media_id == update_attrs.media_id
      assert media_item.media_filepath == update_attrs.media_filepath
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

    test "it also deletes attached tasks" do
      media_item = media_item_fixture()
      task = task_fixture(%{media_item_id: media_item.id})

      assert {:ok, %MediaItem{}} = Media.delete_media_item(media_item)
      assert_raise Ecto.NoResultsError, fn -> Repo.reload!(task) end
    end
  end

  describe "delete_attachments/1" do
    test "deletes the media item's files" do
      media_item = media_item_with_attachments()

      assert {:ok, _} = Media.delete_attachments(media_item)
      refute File.exists?(media_item.media_filepath)
    end

    test "does not delete the media item" do
      media_item = media_item_with_attachments()

      assert {:ok, _} = Media.delete_attachments(media_item)

      assert Repo.reload!(media_item)
    end

    test "deletes the parent folder if it is empty" do
      media_item = media_item_with_attachments()
      root_directory = Path.dirname(media_item.media_filepath)

      assert {:ok, _} = Media.delete_attachments(media_item)
      refute File.exists?(root_directory)
    end

    test "does not delete the parent folder if it is not empty" do
      media_item = media_item_with_attachments()
      root_directory = Path.dirname(media_item.media_filepath)
      File.touch(Path.join([root_directory, "test.txt"]))

      assert {:ok, _} = Media.delete_attachments(media_item)
      assert File.exists?(root_directory)

      :ok = File.rm(Path.join([root_directory, "test.txt"]))
      :ok = File.rmdir(root_directory)
    end
  end

  describe "delete_media_item_and_attachments/1" do
    setup do
      media_item = media_item_with_attachments()
      {:ok, media_item: media_item}
    end

    test "deletes the media item", %{media_item: media_item} do
      assert {:ok, _} = Media.delete_media_item_and_attachments(media_item)
      assert_raise Ecto.NoResultsError, fn -> Media.get_media_item!(media_item.id) end
    end

    test "deletes associated files", %{media_item: media_item} do
      assert File.exists?(media_item.media_filepath)
      assert {:ok, _} = Media.delete_media_item_and_attachments(media_item)
      refute File.exists?(media_item.media_filepath)
    end
  end

  describe "change_media_item/1" do
    test "change_media_item/1 returns a media_item changeset" do
      media_item = media_item_fixture()
      assert %Ecto.Changeset{} = Media.change_media_item(media_item)
    end
  end
end
