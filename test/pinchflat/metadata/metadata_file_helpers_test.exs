defmodule Pinchflat.Metadata.MetadataFileHelpersTest do
  use Pinchflat.DataCase
  import Mox
  import Pinchflat.MediaFixtures

  alias Pinchflat.Metadata.MetadataFileHelpers, as: Helpers

  setup do
    media_item = media_item_fixture()

    {:ok, %{media_item: media_item}}
  end

  setup :verify_on_exit!

  describe "compress_and_store_metadata_for/2" do
    test "returns the filepath", %{media_item: media_item} do
      metadata_map = %{"foo" => "bar"}

      filepath = Helpers.compress_and_store_metadata_for(media_item, metadata_map)

      assert filepath =~ ~r{/media_items/#{media_item.id}/metadata.json.gz}
    end

    test "creates folder structure based on passed record", %{media_item: media_item} do
      metadata_map = %{"foo" => "bar"}

      filepath = Helpers.compress_and_store_metadata_for(media_item, metadata_map)

      assert File.exists?(Path.dirname(filepath))
    end

    test "stores it as compressed JSON", %{media_item: media_item} do
      metadata_map = %{"foo" => "bar"}

      filepath = Helpers.compress_and_store_metadata_for(media_item, metadata_map)
      {:ok, json} = File.open(filepath, [:read, :compressed], &IO.read(&1, :all))

      assert json == Phoenix.json_library().encode!(metadata_map)
    end
  end

  describe "read_compressed_metadata/1" do
    test "returns the compressed and decoded metadata", %{media_item: media_item} do
      metadata_map = %{"foo" => "bar"}

      filepath = Helpers.compress_and_store_metadata_for(media_item, metadata_map)
      {:ok, decoded_json} = Helpers.read_compressed_metadata(filepath)

      assert decoded_json == metadata_map
    end
  end

  describe "download_and_store_thumbnail_for/2" do
    setup do
      # This tests that the HTTP endpoint is being called with every test
      expect(HTTPClientMock, :get, fn url, _headers, _opts ->
        assert url =~ "example.com"

        {:ok, "thumbnail data"}
      end)

      metadata = %{"thumbnail" => "example.com/thumbnail.jpg"}

      {:ok, %{metadata: metadata}}
    end

    test "returns the filepath", %{media_item: media_item, metadata: metadata} do
      filepath = Helpers.download_and_store_thumbnail_for(media_item, metadata)

      assert filepath =~ ~r{/media_items/#{media_item.id}/thumbnail.jpg}
    end

    test "creates folder structure based on passed record", %{media_item: media_item, metadata: metadata} do
      filepath = Helpers.download_and_store_thumbnail_for(media_item, metadata)

      assert File.exists?(Path.dirname(filepath))
    end

    test "the filename and extension is based on the URL", %{media_item: media_item} do
      metadata = %{"thumbnail" => "example.com/maxres.webp"}
      filepath = Helpers.download_and_store_thumbnail_for(media_item, metadata)

      assert Path.basename(filepath) == "maxres.webp"
    end
  end

  describe "parse_upload_date/1" do
    test "returns a date from the given metadata upload date" do
      upload_date = "20210101"

      assert Helpers.parse_upload_date(upload_date) == ~D[2021-01-01]
    end
  end

  describe "series_directory_from_media_filepath/1" do
    test "returns base series directory if filepaths are setup as expected" do
      good_filepaths = [
        "/media/season1/episode.mp4",
        "/media/season 1/episode.mp4",
        "/media/season.1/episode.mp4",
        "/media/season_1/episode.mp4",
        "/media/season-1/episode.mp4",
        "/media/SEASON 1/episode.mp4",
        "/media/SEASON.1/episode.mp4",
        "/media/s1/episode.mp4",
        "/media/s.1/episode.mp4",
        "/media/s_1/episode.mp4",
        "/media/s-1/episode.mp4",
        "/media/s 1/episode.mp4",
        "/media/S1/episode.mp4",
        "/media/S.1/episode.mp4"
      ]

      for filepath <- good_filepaths do
        assert {:ok, "/media"} = Helpers.series_directory_from_media_filepath(filepath)
      end
    end

    test "returns an error if the season filepath can't be determined" do
      bad_filepaths = [
        "/media/1/episode.mp4",
        "/media/(s1)/episode.mp4",
        "/media/episode.mp4",
        "/media/s1e1/episode.mp4",
        "/media/s1 e1/episode.mp4",
        "/media/s1 (something else)/episode.mp4",
        "/media/season1e1/episode.mp4",
        "/media/season1 e1/episode.mp4",
        "/media/seasoning1/episode.mp4",
        "/media/season/episode.mp4",
        "/media/series1/episode.mp4",
        "/media/s/episode.mp4",
        "/media/foo",
        "/media/bar/"
      ]

      for filepath <- bad_filepaths do
        assert {:error, :indeterminable} = Helpers.series_directory_from_media_filepath(filepath)
      end
    end
  end
end
