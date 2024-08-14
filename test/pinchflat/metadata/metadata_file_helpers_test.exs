defmodule Pinchflat.Metadata.MetadataFileHelpersTest do
  use Pinchflat.DataCase

  import Pinchflat.MediaFixtures
  import Pinchflat.SourcesFixtures

  alias Pinchflat.Metadata.MetadataFileHelpers, as: Helpers

  setup do
    media_item = Repo.preload(media_item_fixture(), :source)

    {:ok, %{media_item: media_item}}
  end

  describe "metadata_directory_for/1" do
    test "returns the metadata directory for the given record", %{media_item: media_item} do
      base_metadata_directory = Application.get_env(:pinchflat, :metadata_directory)

      metadata_directory = Helpers.metadata_directory_for(media_item)

      assert metadata_directory == Path.join([base_metadata_directory, "media_items", "#{media_item.id}"])
    end
  end

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
      {:ok, json} = File.open(filepath, [:read, :compressed], &IO.read(&1, :eof))

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
    test "returns the filepath", %{media_item: media_item} do
      stub(YtDlpRunnerMock, :run, fn _url, _opts, _ot, _addl -> {:ok, ""} end)

      filepath = Helpers.download_and_store_thumbnail_for(media_item)

      assert filepath =~ ~r{/media_items/#{media_item.id}/thumbnail.jpg}
    end

    test "calls yt-dlp with the expected options", %{media_item: media_item} do
      expect(YtDlpRunnerMock, :run, fn url, opts, ot, _addl ->
        assert url == media_item.original_url
        assert ot == "after_move:%()j"

        assert opts == [
                 :no_simulate,
                 :skip_download,
                 :write_thumbnail,
                 convert_thumbnail: "jpg",
                 output: "/tmp/test/metadata/media_items/1/thumbnail.%(ext)s"
               ]

        {:ok, ""}
      end)

      Helpers.download_and_store_thumbnail_for(media_item)
    end

    test "sets use_cookies if the source uses cookies" do
      expect(YtDlpRunnerMock, :run, fn _url, _opts, _ot, addl ->
        assert {:use_cookies, true} in addl
        {:ok, ""}
      end)

      source = source_fixture(%{use_cookies: true})
      media_item = Repo.preload(media_item_fixture(%{source_id: source.id}), :source)

      Helpers.download_and_store_thumbnail_for(media_item)
    end

    test "does not set use_cookies if the source does not use cookies" do
      expect(YtDlpRunnerMock, :run, fn _url, _opts, _ot, addl ->
        assert {:use_cookies, false} in addl
        {:ok, ""}
      end)

      source = source_fixture(%{use_cookies: false})
      media_item = Repo.preload(media_item_fixture(%{source_id: source.id}), :source)

      Helpers.download_and_store_thumbnail_for(media_item)
    end

    test "returns nil if yt-dlp fails", %{media_item: media_item} do
      stub(YtDlpRunnerMock, :run, fn _url, _opts, _ot, _addl -> {:error, "error"} end)

      filepath = Helpers.download_and_store_thumbnail_for(media_item)

      assert filepath == nil
    end
  end

  describe "parse_upload_date/1" do
    test "returns a datetime from the given metadata upload date" do
      upload_date = "20210101"

      assert Helpers.parse_upload_date(upload_date) == ~U[2021-01-01 00:00:00Z]
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

  describe "season_and_episode_from_media_filepath/1" do
    test "returns a season and episode if one can be determined" do
      assert {:ok, {"1", "2"}} = Helpers.season_and_episode_from_media_filepath("/foo/s1e2 - test.mp4")
      assert {:ok, {"1", "2"}} = Helpers.season_and_episode_from_media_filepath("/foo/S1E2 - test.mp4")
      assert {:ok, {"001", "002"}} = Helpers.season_and_episode_from_media_filepath("/foo/s001e002 - test.mp4")
      assert {:ok, {"1", "2"}} = Helpers.season_and_episode_from_media_filepath("/foo/s1e2bar - test.mp4")
      assert {:ok, {"1", "2"}} = Helpers.season_and_episode_from_media_filepath("/foo/bar s1e2 - test.mp4")
    end

    test "returns an error if a season and episode can't be determined" do
      assert {:error, :indeterminable} = Helpers.season_and_episode_from_media_filepath("/foo/test.mp4")
      assert {:error, :indeterminable} = Helpers.season_and_episode_from_media_filepath("/foo/s1 - test.mp4")
      assert {:error, :indeterminable} = Helpers.season_and_episode_from_media_filepath("/foo/s1e - test.mp4")
      assert {:error, :indeterminable} = Helpers.season_and_episode_from_media_filepath("/foo/s1etest.mp4")
    end
  end
end
