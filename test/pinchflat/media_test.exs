defmodule Pinchflat.MediaTest do
  use Pinchflat.DataCase

  import Pinchflat.TasksFixtures
  import Pinchflat.MediaFixtures
  import Pinchflat.ProfilesFixtures
  import Pinchflat.SourcesFixtures

  alias Pinchflat.Media
  alias Pinchflat.Media.MediaItem
  alias Pinchflat.Metadata.MetadataFileHelpers

  alias Pinchflat.YtDlp.Media, as: YtDlpMedia

  @invalid_attrs %{title: nil, media_id: nil, media_filepath: nil}

  describe "schema" do
    test "media_metadata is deleted when media_item is deleted" do
      media_item =
        media_item_fixture(%{metadata: %{metadata_filepath: "/metadata.json.gz", thumbnail_filepath: "/thumbnail.jpg"}})

      metadata = media_item.metadata
      assert {:ok, %MediaItem{}} = Media.delete_media_item(media_item)

      assert_raise Ecto.NoResultsError, fn ->
        Repo.reload!(metadata)
      end
    end

    test "can be JSON encoded without error" do
      media_item = media_item_fixture()

      assert {:ok, _} = Phoenix.json_library().encode(media_item)
    end
  end

  describe "list_media_items/0" do
    test "it returns all media_items" do
      media_item = media_item_fixture()
      assert Media.list_media_items() == [media_item]
    end
  end

  describe "list_upgradeable_media_items/0" do
    setup do
      media_profile = media_profile_fixture(%{redownload_delay_days: 4})
      source = source_fixture(%{media_profile_id: media_profile.id, inserted_at: now_minus(10, :days)})

      {:ok, %{media_profile: media_profile, source: source}}
    end

    test "returns media eligible for redownload", %{source: source} do
      media_item =
        media_item_fixture(%{
          source_id: source.id,
          uploaded_at: now_minus(6, :days),
          media_downloaded_at: now_minus(5, :days)
        })

      assert Media.list_upgradeable_media_items() == [media_item]
    end

    test "returns media items that were downloaded in past but still meet redownload delay", %{source: source} do
      media_item =
        media_item_fixture(%{
          source_id: source.id,
          uploaded_at: now_minus(20, :days),
          media_downloaded_at: now_minus(19, :days)
        })

      assert Media.list_upgradeable_media_items() == [media_item]
    end

    test "does not return media items without a media_downloaded_at", %{source: source} do
      _media_item =
        media_item_fixture(%{
          source_id: source.id,
          uploaded_at: now_minus(5, :days),
          media_downloaded_at: nil
        })

      assert Media.list_upgradeable_media_items() == []
    end

    test "does not return media items that are set to prevent download", %{source: source} do
      _media_item =
        media_item_fixture(%{
          source_id: source.id,
          uploaded_at: now_minus(5, :days),
          media_downloaded_at: now(),
          prevent_download: true
        })

      assert Media.list_upgradeable_media_items() == []
    end

    test "does not return media items that have been culled", %{source: source} do
      _media_item =
        media_item_fixture(%{
          source_id: source.id,
          uploaded_at: now_minus(5, :days),
          media_downloaded_at: now(),
          culled_at: now()
        })

      assert Media.list_upgradeable_media_items() == []
    end

    test "does not return media items before the download delay", %{source: source} do
      _media_item =
        media_item_fixture(%{
          source_id: source.id,
          uploaded_at: now_minus(3, :days),
          media_downloaded_at: now_minus(3, :days)
        })

      assert Media.list_upgradeable_media_items() == []
    end

    test "does not return media items that have already been redownloaded", %{source: source} do
      _media_item =
        media_item_fixture(%{
          source_id: source.id,
          uploaded_at: now_minus(5, :days),
          media_downloaded_at: now(),
          media_redownloaded_at: now()
        })

      assert Media.list_upgradeable_media_items() == []
    end

    test "does not return media items that were first downloaded well after the uploaded_at", %{source: source} do
      _media_item =
        media_item_fixture(%{
          source_id: source.id,
          media_downloaded_at: now(),
          uploaded_at: now_minus(20, :days)
        })

      assert Media.list_upgradeable_media_items() == []
    end

    test "does not return media items that were recently uploaded", %{source: source} do
      _media_item =
        media_item_fixture(%{
          source_id: source.id,
          media_downloaded_at: now(),
          uploaded_at: now_minus(2, :days)
        })

      assert Media.list_upgradeable_media_items() == []
    end

    test "does not return media items without a redownload delay" do
      media_profile = media_profile_fixture(%{redownload_delay_days: nil})
      source = source_fixture(%{media_profile_id: media_profile.id})

      _media_item =
        media_item_fixture(%{
          source_id: source.id,
          uploaded_at: now_minus(6, :days),
          media_downloaded_at: now_minus(5, :days)
        })

      assert Media.list_upgradeable_media_items() == []
    end
  end

  describe "list_pending_media_items_for/1" do
    test "it returns pending without a filepath for a given source" do
      source = source_fixture()
      other_source = source_fixture()
      media_item = media_item_fixture(%{source_id: source.id, media_filepath: nil})
      _other_media_item = media_item_fixture(%{source_id: other_source.id, media_filepath: nil})

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
      short = media_item_fixture(%{source_id: source.id, media_filepath: nil, short_form_content: true})

      assert Media.list_pending_media_items_for(source) == [normal, short]
    end

    test "returns only shorts when shorts_behaviour is :only" do
      source = source_fixture(%{media_profile_id: media_profile_fixture(%{shorts_behaviour: :only}).id})
      _normal = media_item_fixture(%{source_id: source.id, media_filepath: nil})
      short = media_item_fixture(%{source_id: source.id, media_filepath: nil, short_form_content: true})

      assert Media.list_pending_media_items_for(source) == [short]
    end

    test "returns only normal media when shorts_behaviour is :exclude" do
      source = source_fixture(%{media_profile_id: media_profile_fixture(%{shorts_behaviour: :exclude}).id})
      normal = media_item_fixture(%{source_id: source.id, media_filepath: nil})
      _short = media_item_fixture(%{source_id: source.id, media_filepath: nil, short_form_content: true})

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
      short = media_item_fixture(%{source_id: source.id, media_filepath: nil, short_form_content: true})

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
      short = media_item_fixture(%{source_id: source.id, media_filepath: nil, short_form_content: true})

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
      _short = media_item_fixture(%{source_id: source.id, media_filepath: nil, short_form_content: true})

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
      short = media_item_fixture(%{source_id: source.id, media_filepath: nil, short_form_content: true})

      assert Media.list_pending_media_items_for(source) == [short]
    end
  end

  describe "list_pending_media_items_for/1 when testing cutoff dates" do
    test "does not return media items with an upload date before the cutoff date" do
      source = source_fixture(%{download_cutoff_date: now_minus(1, :day)})

      _old_media_item =
        media_item_fixture(%{source_id: source.id, media_filepath: nil, uploaded_at: now_minus(2, :days)})

      new_media_item = media_item_fixture(%{source_id: source.id, media_filepath: nil, uploaded_at: now()})

      assert Media.list_pending_media_items_for(source) == [new_media_item]
    end

    test "does not apply a cutoff if there is no cutoff date" do
      source = source_fixture(%{download_cutoff_date: nil})

      old_media_item =
        media_item_fixture(%{source_id: source.id, media_filepath: nil, uploaded_at: now_minus(2, :days)})

      new_media_item = media_item_fixture(%{source_id: source.id, media_filepath: nil, uploaded_at: now()})

      assert Media.list_pending_media_items_for(source) == [old_media_item, new_media_item]
    end
  end

  describe "list_pending_media_items_for/1 when testing title regex" do
    test "returns only media items that match the title regex" do
      source = source_fixture(%{title_filter_regex: "(?i)^FOO$"})

      matching_media_item = media_item_fixture(%{source_id: source.id, media_filepath: nil, title: "foo"})
      _non_matching_media_item = media_item_fixture(%{source_id: source.id, media_filepath: nil, title: "bar"})

      assert Media.list_pending_media_items_for(source) == [matching_media_item]
    end

    test "does not apply a regex if none is specified" do
      source = source_fixture(%{title_filter_regex: nil})

      media_item_one = media_item_fixture(%{source_id: source.id, media_filepath: nil, title: "foo"})
      media_item_two = media_item_fixture(%{source_id: source.id, media_filepath: nil, title: "bar"})

      assert Media.list_pending_media_items_for(source) == [media_item_one, media_item_two]
    end
  end

  describe "list_pending_media_items_for/1 when min and max durations" do
    test "returns media items that meet the min and max duration" do
      source = source_fixture(%{min_duration_seconds: 10, max_duration_seconds: 20})

      _short_media_item = media_item_fixture(%{source_id: source.id, media_filepath: nil, duration_seconds: 5})
      normal_media_item = media_item_fixture(%{source_id: source.id, media_filepath: nil, duration_seconds: 15})
      _long_media_item = media_item_fixture(%{source_id: source.id, media_filepath: nil, duration_seconds: 25})

      assert Media.list_pending_media_items_for(source) == [normal_media_item]
    end

    test "does not apply a min duration if none is specified" do
      source = source_fixture(%{min_duration_seconds: nil, max_duration_seconds: 20})

      short_media_item = media_item_fixture(%{source_id: source.id, media_filepath: nil, duration_seconds: 5})
      normal_media_item = media_item_fixture(%{source_id: source.id, media_filepath: nil, duration_seconds: 15})
      _long_media_item = media_item_fixture(%{source_id: source.id, media_filepath: nil, duration_seconds: 25})

      assert Media.list_pending_media_items_for(source) == [short_media_item, normal_media_item]
    end

    test "does not apply a max duration if none is specified" do
      source = source_fixture(%{min_duration_seconds: 10, max_duration_seconds: nil})

      _short_media_item = media_item_fixture(%{source_id: source.id, media_filepath: nil, duration_seconds: 5})
      normal_media_item = media_item_fixture(%{source_id: source.id, media_filepath: nil, duration_seconds: 15})
      long_media_item = media_item_fixture(%{source_id: source.id, media_filepath: nil, duration_seconds: 25})

      assert Media.list_pending_media_items_for(source) == [normal_media_item, long_media_item]
    end

    test "does not apply a min or max duration if none are specified" do
      source = source_fixture(%{min_duration_seconds: nil, max_duration_seconds: nil})

      short_media_item = media_item_fixture(%{source_id: source.id, media_filepath: nil, duration_seconds: 5})
      normal_media_item = media_item_fixture(%{source_id: source.id, media_filepath: nil, duration_seconds: 15})
      long_media_item = media_item_fixture(%{source_id: source.id, media_filepath: nil, duration_seconds: 25})

      assert Media.list_pending_media_items_for(source) == [short_media_item, normal_media_item, long_media_item]
    end
  end

  describe "list_pending_media_items_for/1 when testing download prevention" do
    test "returns only media items that are not prevented from downloading" do
      source = source_fixture()
      _prevented_media_item = media_item_fixture(%{source_id: source.id, media_filepath: nil, prevent_download: true})
      media_item = media_item_fixture(%{source_id: source.id, media_filepath: nil, prevent_download: false})

      assert Media.list_pending_media_items_for(source) == [media_item]
    end
  end

  describe "pending_download?/1" do
    test "returns true when the media hasn't been downloaded" do
      media_item = media_item_fixture(%{media_filepath: nil})

      assert Media.pending_download?(media_item)
    end

    test "returns false if the media has been downloaded" do
      media_item = media_item_fixture(%{media_filepath: "/video/#{Faker.File.file_name(:video)}"})

      refute Media.pending_download?(media_item)
    end

    test "returns false if the media hasn't been downloaded but the profile doesn't DL shorts" do
      source = source_fixture(%{media_profile_id: media_profile_fixture(%{shorts_behaviour: :exclude}).id})
      media_item = media_item_fixture(%{source_id: source.id, media_filepath: nil, short_form_content: true})

      refute Media.pending_download?(media_item)
    end

    test "returns false if the media hasn't been downloaded but the profile doesn't DL livestreams" do
      source = source_fixture(%{media_profile_id: media_profile_fixture(%{livestream_behaviour: :exclude}).id})
      media_item = media_item_fixture(%{source_id: source.id, media_filepath: nil, livestream: true})

      refute Media.pending_download?(media_item)
    end

    test "returns true if there is a cutoff date before the media's upload date" do
      source = source_fixture(%{download_cutoff_date: now_minus(2, :days)})
      media_item = media_item_fixture(%{source_id: source.id, media_filepath: nil, uploaded_at: now_minus(1, :day)})

      assert Media.pending_download?(media_item)
    end

    test "returns true if the cutoff date is equal to the upload date" do
      source = source_fixture(%{download_cutoff_date: now_minus(2, :days)})
      media_item = media_item_fixture(%{source_id: source.id, media_filepath: nil, uploaded_at: now_minus(2, :days)})

      assert Media.pending_download?(media_item)
    end

    test "returns false if there is a cutoff date after the media's upload date" do
      source = source_fixture(%{download_cutoff_date: now_minus(1, :day)})
      media_item = media_item_fixture(%{source_id: source.id, media_filepath: nil, uploaded_at: now_minus(2, :days)})

      refute Media.pending_download?(media_item)
    end

    test "returns true if there is no cutoff date" do
      source = source_fixture(%{download_cutoff_date: nil})
      media_item = media_item_fixture(%{source_id: source.id, media_filepath: nil, uploaded_at: now_minus(1, :day)})

      assert Media.pending_download?(media_item)
    end

    test "returns true if the content matches the title regex" do
      source = source_fixture(%{title_filter_regex: "(?i)^FOO$"})
      media_item = media_item_fixture(%{source_id: source.id, media_filepath: nil, title: "foo"})

      assert Media.pending_download?(media_item)
    end

    test "returns false if the content doesn't match the title regex" do
      source = source_fixture(%{title_filter_regex: "(?i)^FOO$"})
      media_item = media_item_fixture(%{source_id: source.id, media_filepath: nil, title: "bar"})

      refute Media.pending_download?(media_item)
    end

    test "return true if there is no title regex" do
      source = source_fixture(%{title_filter_regex: nil})
      media_item = media_item_fixture(%{source_id: source.id, media_filepath: nil, title: "foo"})

      assert Media.pending_download?(media_item)
    end

    test "returns true if the duration is between the min and max" do
      source = source_fixture(%{min_duration_seconds: 10, max_duration_seconds: 20})
      media_item = media_item_fixture(%{source_id: source.id, media_filepath: nil, duration_seconds: 15})

      assert Media.pending_download?(media_item)
    end

    test "returns false if the duration is below the min" do
      source = source_fixture(%{min_duration_seconds: 10, max_duration_seconds: 20})
      media_item = media_item_fixture(%{source_id: source.id, media_filepath: nil, duration_seconds: 5})

      refute Media.pending_download?(media_item)
    end

    test "returns false if the duration is above the max" do
      source = source_fixture(%{min_duration_seconds: 10, max_duration_seconds: 20})
      media_item = media_item_fixture(%{source_id: source.id, media_filepath: nil, duration_seconds: 25})

      refute Media.pending_download?(media_item)
    end

    test "returns true if there is no min or max duration" do
      source = source_fixture(%{min_duration_seconds: nil, max_duration_seconds: nil})
      media_item = media_item_fixture(%{source_id: source.id, media_filepath: nil, duration_seconds: 15})

      assert Media.pending_download?(media_item)
    end

    test "returns true if the media item is not prevented from downloading" do
      media_item = media_item_fixture(%{media_filepath: nil, prevent_download: false})

      assert Media.pending_download?(media_item)
    end

    test "returns false if the media item is prevented from downloading" do
      media_item = media_item_fixture(%{media_filepath: nil, prevent_download: true})

      refute Media.pending_download?(media_item)
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

    test "doesn't set matching_search_term to nil if one of the attributes we search on is null" do
      media_item_fixture(%{title: "foobar baz", description: nil})

      assert [%{matching_search_term: matching_search_term}] = Media.search("baz")
      refute is_nil(matching_search_term)
    end

    test "optionally lets you specify a limit" do
      media_item_fixture(%{title: "The small gray dog"})

      assert [_] = Media.search("dog", limit: 1)
    end

    test "returns an empty list when the search term is blank" do
      assert [] = Media.search("")
    end

    test "returns an empty list when the search term is nil" do
      assert [] = Media.search(nil)
    end

    test "doesn't blow up if there's an apostrophe or quotes in the search term" do
      assert [] = Media.search("don't expl'ode")
      assert [] = Media.search(~s(dont expl"o"de))
      assert [] = Media.search(~s(dont explo"de))
    end

    test "doesn't blow up if there is a trailing operand" do
      assert [] = Media.search("foo OR")
      assert [] = Media.search("foo AND")
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
        media_filepath: "/video/#{Faker.File.file_name(:video)}",
        source_id: source_fixture().id,
        original_url: "https://www.youtube.com/channel/#{Faker.String.base64(12)}",
        uploaded_at: now()
      }

      assert {:ok, %MediaItem{} = media_item} = Media.create_media_item(valid_attrs)

      assert media_item.title == valid_attrs.title
      assert media_item.media_id == valid_attrs.media_id
      assert media_item.media_filepath == valid_attrs.media_filepath
    end

    test "automatically sets the UUID" do
      valid_attrs = %{
        media_id: Faker.String.base64(12),
        title: Faker.Commerce.product_name(),
        media_filepath: "/video/#{Faker.File.file_name(:video)}",
        source_id: source_fixture().id,
        original_url: "https://www.youtube.com/channel/#{Faker.String.base64(12)}",
        uploaded_at: now()
      }

      assert {:ok, %MediaItem{} = media_item} = Media.create_media_item(valid_attrs)

      assert String.length(media_item.uuid) == 36
    end

    test "UUID is not writable by the user" do
      valid_attrs = %{
        media_id: Faker.String.base64(12),
        title: Faker.Commerce.product_name(),
        media_filepath: "/video/#{Faker.File.file_name(:video)}",
        source_id: source_fixture().id,
        original_url: "https://www.youtube.com/channel/#{Faker.String.base64(12)}",
        uploaded_at: now(),
        uuid: "some-uuid"
      }

      assert {:ok, %MediaItem{} = media_item} = Media.create_media_item(valid_attrs)

      assert String.length(media_item.uuid) == 36
    end

    test "creating with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Media.create_media_item(@invalid_attrs)
    end
  end

  describe "create_media_item_from_backend_attrs/2" do
    test "creates a media item for a given source and attributes" do
      source = source_fixture()

      media_attrs =
        media_attributes_return_fixture()
        |> Phoenix.json_library().decode!()
        |> YtDlpMedia.response_to_struct()

      assert {:ok, %MediaItem{} = media_item} = Media.create_media_item_from_backend_attrs(source, media_attrs)

      assert media_item.source_id == source.id
      assert media_item.title == media_attrs.title
      assert media_item.media_id == media_attrs.media_id
      assert media_item.original_url == media_attrs.original_url
      assert media_item.description == media_attrs.description
    end

    test "updates the media item if it already exists" do
      source = source_fixture()

      media_attrs =
        media_attributes_return_fixture()
        |> Phoenix.json_library().decode!()
        |> YtDlpMedia.response_to_struct()

      different_attrs = %YtDlpMedia{media_attrs | title: "Different title"}

      assert {:ok, %MediaItem{} = media_item_1} = Media.create_media_item_from_backend_attrs(source, media_attrs)
      assert {:ok, %MediaItem{} = media_item_2} = Media.create_media_item_from_backend_attrs(source, different_attrs)

      assert media_item_1.id == media_item_2.id
      assert Repo.reload(media_item_2).title == different_attrs.title
    end

    test "doesn't update fields like playlist_index" do
      source = source_fixture()

      media_attrs =
        media_attributes_return_fixture()
        |> Phoenix.json_library().decode!()
        |> Map.put("playlist_index", 1)
        |> YtDlpMedia.response_to_struct()

      different_attrs = %YtDlpMedia{media_attrs | playlist_index: 9999}

      assert {:ok, %MediaItem{} = _media_item_1} = Media.create_media_item_from_backend_attrs(source, media_attrs)
      assert {:ok, %MediaItem{} = media_item_2} = Media.create_media_item_from_backend_attrs(source, different_attrs)

      assert Repo.reload(media_item_2).playlist_index == media_attrs.playlist_index
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

    test "updating strips playlist_index from the provided attrs" do
      media_item = media_item_fixture(playlist_index: 5)

      update_attrs = %{
        media_id: Faker.String.base64(12),
        title: Faker.Commerce.product_name(),
        media_filepath: "/video/#{Faker.File.file_name(:video)}",
        source_id: source_fixture().id,
        playlist_index: 1
      }

      assert {:ok, %MediaItem{} = media_item} = Media.update_media_item(media_item, update_attrs)
      assert media_item.playlist_index == 5
    end

    test "updating with invalid data returns error changeset" do
      media_item = media_item_fixture()
      assert {:error, %Ecto.Changeset{}} = Media.update_media_item(media_item, @invalid_attrs)
      assert media_item == Media.get_media_item!(media_item.id)
    end
  end

  describe "delete_media_item/2" do
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

    test "does not delete the media_item's files by default" do
      media_item = media_item_with_attachments()

      assert {:ok, _} = Media.delete_media_item(media_item)
      assert File.exists?(media_item.media_filepath)
    end

    test "does delete the media item's metadata files" do
      stub(YtDlpRunnerMock, :run, fn _url, :download_thumbnail, _opts, _ot, _addl -> {:ok, ""} end)
      media_item = Repo.preload(media_item_with_attachments(), [:metadata, :source])

      update_attrs = %{
        metadata: %{
          metadata_filepath: MetadataFileHelpers.compress_and_store_metadata_for(media_item, %{}),
          thumbnail_filepath: MetadataFileHelpers.download_and_store_thumbnail_for(media_item)
        }
      }

      {:ok, updated_media_item} = Media.update_media_item(media_item, update_attrs)

      assert {:ok, _} = Media.delete_media_item(updated_media_item)
      refute File.exists?(updated_media_item.metadata.metadata_filepath)
    end
  end

  describe "delete_media_item/2 when testing file deletion" do
    setup do
      stub(UserScriptRunnerMock, :run, fn _event_type, _data -> {:ok, "", 0} end)

      :ok
    end

    test "deletes the media item's files" do
      media_item = media_item_with_attachments()

      assert {:ok, _} = Media.delete_media_item(media_item, delete_files: true)
      refute File.exists?(media_item.media_filepath)
    end

    test "deletes the media item's metadata files" do
      stub(YtDlpRunnerMock, :run, fn _url, :download_thumbnail, _opts, _ot, _addl -> {:ok, ""} end)
      media_item = Repo.preload(media_item_with_attachments(), [:metadata, :source])

      update_attrs = %{
        metadata: %{
          metadata_filepath: MetadataFileHelpers.compress_and_store_metadata_for(media_item, %{}),
          thumbnail_filepath: MetadataFileHelpers.download_and_store_thumbnail_for(media_item)
        }
      }

      {:ok, updated_media_item} = Media.update_media_item(media_item, update_attrs)

      assert {:ok, _} = Media.delete_media_item(updated_media_item, delete_files: true)
      refute File.exists?(updated_media_item.metadata.metadata_filepath)
    end

    test "deletion deletes the media_item" do
      media_item = media_item_fixture()
      assert {:ok, %MediaItem{}} = Media.delete_media_item(media_item, delete_files: true)
      assert_raise Ecto.NoResultsError, fn -> Media.get_media_item!(media_item.id) end
    end

    test "deletes the parent folder if it is empty" do
      media_item = media_item_with_attachments()
      root_directory = Path.dirname(media_item.media_filepath)

      assert {:ok, _} = Media.delete_media_item(media_item, delete_files: true)
      refute File.exists?(root_directory)
    end

    test "does not delete the parent folder if it is not empty" do
      media_item = media_item_with_attachments()
      root_directory = Path.dirname(media_item.media_filepath)
      File.touch(Path.join([root_directory, "test.txt"]))

      assert {:ok, _} = Media.delete_media_item(media_item, delete_files: true)
      assert File.exists?(root_directory)

      :ok = File.rm(Path.join([root_directory, "test.txt"]))
      :ok = File.rmdir(root_directory)
    end

    test "calls the user script runner" do
      media_item = media_item_with_attachments()

      expect(UserScriptRunnerMock, :run, fn :media_deleted, data ->
        assert data.id == media_item.id

        {:ok, "", 0}
      end)

      assert {:ok, _} = Media.delete_media_item(media_item, delete_files: true)
    end
  end

  describe "delete_media_files/2" do
    setup do
      stub(UserScriptRunnerMock, :run, fn _event_type, _data -> {:ok, "", 0} end)

      :ok
    end

    test "does not delete the media_item" do
      media_item = media_item_fixture()

      assert {:ok, %MediaItem{}} = Media.delete_media_files(media_item)
      assert Repo.reload!(media_item)
    end

    test "deletes attached tasks" do
      media_item = media_item_fixture()
      task = task_fixture(%{media_item_id: media_item.id})

      assert {:ok, %MediaItem{}} = Media.delete_media_files(media_item)
      assert_raise Ecto.NoResultsError, fn -> Repo.reload!(task) end
    end

    test "deletes the media_item's files" do
      media_item = media_item_with_attachments()

      assert File.exists?(media_item.media_filepath)
      assert {:ok, _} = Media.delete_media_files(media_item)
      refute File.exists?(media_item.media_filepath)
    end

    test "does not delete the media item's metadata files" do
      stub(YtDlpRunnerMock, :run, fn _url, :download_thumbnail, _opts, _ot, _addl -> {:ok, ""} end)
      media_item = Repo.preload(media_item_with_attachments(), [:metadata, :source])

      update_attrs = %{
        metadata: %{
          metadata_filepath: MetadataFileHelpers.compress_and_store_metadata_for(media_item, %{}),
          thumbnail_filepath: MetadataFileHelpers.download_and_store_thumbnail_for(media_item)
        }
      }

      {:ok, updated_media_item} = Media.update_media_item(media_item, update_attrs)
      metadata = Repo.preload(updated_media_item, :metadata).metadata

      assert {:ok, _} = Media.delete_media_files(updated_media_item)
      assert Repo.reload(metadata)
      assert File.exists?(updated_media_item.metadata.metadata_filepath)

      # cleanup
      Media.delete_media_item(updated_media_item, delete_files: true)
    end

    test "can take additional attributes update media item" do
      media_item = media_item_with_attachments()

      assert {:ok, updated_media_item} = Media.delete_media_files(media_item, %{prevent_download: true})
      assert updated_media_item.prevent_download
    end

    test "calls the user script runner" do
      media_item = media_item_with_attachments()

      expect(UserScriptRunnerMock, :run, fn :media_deleted, data ->
        assert data.id == media_item.id

        {:ok, "", 0}
      end)

      assert {:ok, _} = Media.delete_media_files(media_item)
    end
  end

  describe "change_media_item/1" do
    test "change_media_item/1 returns a media_item changeset" do
      media_item = media_item_fixture()
      assert %Ecto.Changeset{} = Media.change_media_item(media_item)
    end
  end

  describe "change_media_item/1 when testing upload_date_index and source is a channel" do
    test "upload_date_index is set to 99 if it's the only video uploaded that day" do
      source = source_fixture(%{collection_type: :channel})
      media_item = media_item_fixture(%{source_id: source.id, uploaded_at: now()})

      assert media_item.upload_date_index == 99
    end

    test "upload_date_index is set to 98 if it's the second video uploaded that day" do
      source = source_fixture(%{collection_type: :channel})

      media_item_one = media_item_fixture(%{source_id: source.id, uploaded_at: now()})
      media_item_two = media_item_fixture(%{source_id: source.id, uploaded_at: now()})

      assert media_item_one.upload_date_index == 99
      assert media_item_two.upload_date_index == 98
    end

    test "upload_date_index doesn't decrement if the video is uploaded on a different day" do
      source = source_fixture(%{collection_type: :channel})

      media_item_new = media_item_fixture(%{source_id: source.id, uploaded_at: now()})
      media_item_old = media_item_fixture(%{source_id: source.id, uploaded_at: now_minus(1, :day)})

      assert media_item_new.upload_date_index == 99
      assert media_item_old.upload_date_index == 99
    end

    test "recomputes upload_date_index if an upload_date is changed...somehow" do
      source = source_fixture(%{collection_type: :channel})

      media_item_new = media_item_fixture(%{source_id: source.id, uploaded_at: now()})
      media_item_old = media_item_fixture(%{source_id: source.id, uploaded_at: now_minus(1, :day)})

      {:ok, updated_media_item} = Media.update_media_item(media_item_old, %{uploaded_at: now()})

      assert media_item_new.upload_date_index == 99
      assert updated_media_item.upload_date_index == 98
    end

    test "upload_date_index doesn't decrement if the video is for a different source" do
      source_one = source_fixture(%{collection_type: :channel})
      source_two = source_fixture(%{collection_type: :channel})

      media_item_one = media_item_fixture(%{source_id: source_one.id, uploaded_at: now()})
      media_item_two = media_item_fixture(%{source_id: source_two.id, uploaded_at: now()})

      assert media_item_one.upload_date_index == 99
      assert media_item_two.upload_date_index == 99
    end

    test "upload_date_index doesn't decrement if the a video's upload_date is updated but doesn't change" do
      source = source_fixture(%{collection_type: :channel})

      media_item_one = media_item_fixture(%{source_id: source.id, uploaded_at: now()})
      _media_item_two = media_item_fixture(%{source_id: source.id, uploaded_at: now()})

      {:ok, updated_media_item} = Media.update_media_item(media_item_one, %{uploaded_at: now(), title: "New title"})

      assert updated_media_item.upload_date_index == 99
    end

    test "upload_date_index doesn't increment if the a video's upload_date is changed to the same day" do
      source = source_fixture(%{collection_type: :channel})

      media_item_one = media_item_fixture(%{source_id: source.id, uploaded_at: now()})
      _media_item_two = media_item_fixture(%{source_id: source.id, uploaded_at: now()})

      {:ok, updated_media_item} =
        Media.update_media_item(media_item_one, %{uploaded_at: now_plus(1, :minute), title: "New title"})

      assert updated_media_item.upload_date_index == 99
    end
  end

  describe "change_media_item/1 when testing upload_date_index and source is a playlist" do
    test "upload_date_index is set to 0 if it's the only video uploaded that day" do
      source = source_fixture(%{collection_type: :playlist})
      media_item = media_item_fixture(%{source_id: source.id, uploaded_at: now()})

      assert media_item.upload_date_index == 0
    end

    test "upload_date_index is set to 1 if it's the second video uploaded that day" do
      source = source_fixture(%{collection_type: :playlist})

      media_item_one = media_item_fixture(%{source_id: source.id, uploaded_at: now()})
      media_item_two = media_item_fixture(%{source_id: source.id, uploaded_at: now()})

      assert media_item_one.upload_date_index == 0
      assert media_item_two.upload_date_index == 1
    end

    test "upload_date_index doesn't increment if the video is uploaded on a different day" do
      source = source_fixture(%{collection_type: :playlist})

      media_item_new = media_item_fixture(%{source_id: source.id, uploaded_at: now()})
      media_item_old = media_item_fixture(%{source_id: source.id, uploaded_at: now_minus(1, :day)})

      assert media_item_new.upload_date_index == 0
      assert media_item_old.upload_date_index == 0
    end

    test "recomputes upload_date_index if an upload_date is changed...somehow" do
      source = source_fixture(%{collection_type: :playlist})

      media_item_new = media_item_fixture(%{source_id: source.id, uploaded_at: now()})
      media_item_old = media_item_fixture(%{source_id: source.id, uploaded_at: now_minus(1, :day)})

      {:ok, updated_media_item} = Media.update_media_item(media_item_old, %{uploaded_at: now()})

      assert media_item_new.upload_date_index == 0
      assert updated_media_item.upload_date_index == 1
    end

    test "upload_date_index doesn't increment if the video is for a different source" do
      source_one = source_fixture(%{collection_type: :playlist})
      source_two = source_fixture(%{collection_type: :playlist})

      media_item_one = media_item_fixture(%{source_id: source_one.id, uploaded_at: now()})
      media_item_two = media_item_fixture(%{source_id: source_two.id, uploaded_at: now()})

      assert media_item_one.upload_date_index == 0
      assert media_item_two.upload_date_index == 0
    end

    test "upload_date_index doesn't increment if the a video's upload_date is updated but doesn't change" do
      source = source_fixture(%{collection_type: :playlist})

      media_item_one = media_item_fixture(%{source_id: source.id, uploaded_at: now()})
      _media_item_two = media_item_fixture(%{source_id: source.id, uploaded_at: now()})

      {:ok, updated_media_item} = Media.update_media_item(media_item_one, %{uploaded_at: now(), title: "New title"})

      assert updated_media_item.upload_date_index == 0
    end

    test "upload_date_index doesn't increment if the a video's upload_date is changed to the same day" do
      source = source_fixture(%{collection_type: :playlist})

      media_item_one = media_item_fixture(%{source_id: source.id, uploaded_at: now()})
      _media_item_two = media_item_fixture(%{source_id: source.id, uploaded_at: now()})

      {:ok, updated_media_item} =
        Media.update_media_item(media_item_one, %{uploaded_at: now_plus(1, :minute), title: "New title"})

      assert updated_media_item.upload_date_index == 0
    end
  end
end
