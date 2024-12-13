defmodule Pinchflat.Downloading.MediaDownloaderTest do
  use Pinchflat.DataCase

  import Pinchflat.MediaFixtures
  import Pinchflat.SourcesFixtures
  import Pinchflat.ProfilesFixtures

  alias Pinchflat.Media
  alias Pinchflat.Downloading.MediaDownloader

  setup do
    media_item =
      Repo.preload(
        media_item_fixture(%{title: "Something", media_filepath: nil}),
        [:metadata, source: :media_profile]
      )

    stub(HTTPClientMock, :get, fn _url, _headers, _opts -> {:ok, ""} end)
    stub(YtDlpRunnerMock, :run, fn _url, :get_downloadable_status, _opts, _ot -> {:ok, "{}"} end)

    {:ok, %{media_item: media_item}}
  end

  describe "download_for_media_item/3" do
    test "calls the backend runner", %{media_item: media_item} do
      expect(YtDlpRunnerMock, :run, 1, fn url, :download, _opts, ot, addl ->
        assert url == media_item.original_url
        assert ot == "after_move:%()j"
        assert [{:output_filepath, filepath} | _] = addl
        assert is_binary(filepath)

        {:ok, render_metadata(:media_metadata)}
      end)

      expect(YtDlpRunnerMock, :run, 1, fn _url, :download_thumbnail, _opts, _ot, _addl_args -> {:ok, ""} end)

      assert {:ok, _} = MediaDownloader.download_for_media_item(media_item)
    end

    test "saves the metadata filepath to the database", %{media_item: media_item} do
      expect(YtDlpRunnerMock, :run, 1, fn _url, :download, _opts, _ot, _addl ->
        {:ok, render_metadata(:media_metadata)}
      end)

      expect(YtDlpRunnerMock, :run, 1, fn _url, :download_thumbnail, _opts, _ot, _addl_args -> {:ok, ""} end)

      assert is_nil(media_item.metadata)
      assert {:ok, updated_media_item} = MediaDownloader.download_for_media_item(media_item)

      assert updated_media_item.metadata.metadata_filepath =~ "media_items/#{media_item.id}/metadata.json.gz"
      assert updated_media_item.metadata.thumbnail_filepath =~ "media_items/#{media_item.id}/thumbnail.jpg"
    end

    test "errors for non-downloadable media are passed through", %{media_item: media_item} do
      expect(YtDlpRunnerMock, :run, fn _url, :get_downloadable_status, _opts, _ot ->
        {:ok, Phoenix.json_library().encode!(%{"live_status" => "is_live"})}
      end)

      assert {:error, :unsuitable_for_download} = MediaDownloader.download_for_media_item(media_item)
    end

    test "non-recoverable errors are passed through", %{media_item: media_item} do
      expect(YtDlpRunnerMock, :run, fn _url, :download, _opts, _ot, _addl ->
        {:error, :some_error, 1}
      end)

      assert {:error, :some_error} = MediaDownloader.download_for_media_item(media_item)
    end

    test "unknown errors are passed through", %{media_item: media_item} do
      expect(YtDlpRunnerMock, :run, fn _url, :download, _opts, _ot, _addl ->
        {:error, :some_error}
      end)

      assert {:error, message} = MediaDownloader.download_for_media_item(media_item)
      assert message == "Unknown error: {:error, :some_error}"
    end
  end

  describe "download_for_media_item/3 when testing non-downloadable media" do
    test "calls the download runner if the media is currently downloadable", %{media_item: media_item} do
      expect(YtDlpRunnerMock, :run, fn _url, :get_downloadable_status, _opts, _ot ->
        {:ok, Phoenix.json_library().encode!(%{"live_status" => "was_live"})}
      end)

      expect(YtDlpRunnerMock, :run, 1, fn _url, :download, _opts, _ot, _addl ->
        {:ok, render_metadata(:media_metadata)}
      end)

      expect(YtDlpRunnerMock, :run, 1, fn _url, :download_thumbnail, _opts, _ot, _addl_args -> {:ok, ""} end)

      assert {:ok, _} = MediaDownloader.download_for_media_item(media_item)
    end

    test "does not call the download runner if the media is not downloadable", %{media_item: media_item} do
      expect(YtDlpRunnerMock, :run, fn _url, :get_downloadable_status, _opts, _ot ->
        {:ok, Phoenix.json_library().encode!(%{"live_status" => "is_live"})}
      end)

      expect(YtDlpRunnerMock, :run, 0, fn _url, :download, _opts, _ot, _addl -> {:ok, ""} end)

      assert {:error, :unsuitable_for_download} = MediaDownloader.download_for_media_item(media_item)
    end

    test "returns unexpected errors from the download status determination method", %{media_item: media_item} do
      expect(YtDlpRunnerMock, :run, fn _url, :get_downloadable_status, _opts, _ot -> {:error, :what_tha} end)

      assert {:error, "Unknown error: {:error, :what_tha}"} = MediaDownloader.download_for_media_item(media_item)
    end
  end

  describe "download_for_media_item/3 when testing override options" do
    test "includes override opts if specified", %{media_item: media_item} do
      expect(YtDlpRunnerMock, :run, 1, fn _url, :download, opts, _ot, _addl ->
        refute :force_overwrites in opts
        assert :no_force_overwrites in opts

        {:ok, render_metadata(:media_metadata)}
      end)

      expect(YtDlpRunnerMock, :run, 1, fn _url, :download_thumbnail, _opts, _ot, _addl -> {:ok, ""} end)

      override_opts = [overwrite_behaviour: :no_force_overwrites]

      assert {:ok, _} = MediaDownloader.download_for_media_item(media_item, override_opts)
    end
  end

  describe "download_for_media_item/3 when testing cookie usage" do
    test "sets use_cookies if the source uses cookies" do
      expect(YtDlpRunnerMock, :run, 1, fn _url, :download, _opts, _ot, addl ->
        assert {:use_cookies, true} in addl
        {:ok, render_metadata(:media_metadata)}
      end)

      expect(YtDlpRunnerMock, :run, 1, fn _url, :download_thumbnail, _opts, _ot, _addl_args -> {:ok, ""} end)

      source = source_fixture(%{use_cookies: true})
      media_item = media_item_fixture(%{source_id: source.id})

      assert {:ok, _} = MediaDownloader.download_for_media_item(media_item)
    end

    test "does not set use_cookies if the source does not use cookies" do
      expect(YtDlpRunnerMock, :run, 1, fn _url, :download, _opts, _ot, addl ->
        assert {:use_cookies, false} in addl
        {:ok, render_metadata(:media_metadata)}
      end)

      expect(YtDlpRunnerMock, :run, 1, fn _url, :download_thumbnail, _opts, _ot, _addl_args -> {:ok, ""} end)

      source = source_fixture(%{use_cookies: false})
      media_item = media_item_fixture(%{source_id: source.id})

      assert {:ok, _} = MediaDownloader.download_for_media_item(media_item)
    end
  end

  describe "download_for_media_item/3 when testing retries" do
    test "returns a recovered tuple on recoverable errors", %{media_item: media_item} do
      message = "Unable to communicate with SponsorBlock"

      expect(YtDlpRunnerMock, :run, fn _url, :download, _opts, _ot, _addl ->
        {:error, message, 1}
      end)

      assert {:recovered, ^message} = MediaDownloader.download_for_media_item(media_item)
    end

    test "attempts to update the media item on recoverable errors", %{media_item: media_item} do
      message = "Unable to communicate with SponsorBlock"

      expect(YtDlpRunnerMock, :run, 1, fn _url, :download, _opts, _ot, addl ->
        [{:output_filepath, filepath} | _] = addl
        File.write(filepath, render_metadata(:media_metadata))

        {:error, message, 1}
      end)

      expect(YtDlpRunnerMock, :run, 1, fn _url, :download_thumbnail, _opts, _ot, _addl_args -> {:ok, ""} end)

      assert {:recovered, ^message} = MediaDownloader.download_for_media_item(media_item)
      media_item = Repo.reload(media_item)

      assert DateTime.diff(DateTime.utc_now(), media_item.media_downloaded_at) < 2
      assert String.ends_with?(media_item.media_filepath, ".mkv")
    end
  end

  describe "download_for_media_item/3 when testing media_item attributes" do
    setup do
      stub(YtDlpRunnerMock, :run, fn
        _url, :download, _opts, _ot, _addl -> {:ok, render_metadata(:media_metadata)}
        _url, :download_thumbnail, _opts, _ot, _addl -> {:ok, ""}
      end)

      :ok
    end

    test "sets the media_downloaded_at", %{media_item: media_item} do
      assert media_item.media_downloaded_at == nil
      assert {:ok, updated_media_item} = MediaDownloader.download_for_media_item(media_item)
      assert DateTime.diff(DateTime.utc_now(), updated_media_item.media_downloaded_at) < 2
    end

    test "sets the culled_at to nil", %{media_item: media_item} do
      Media.update_media_item(media_item, %{culled_at: DateTime.utc_now()})
      assert {:ok, updated_media_item} = MediaDownloader.download_for_media_item(media_item)
      assert updated_media_item.culled_at == nil
    end

    test "extracts the title", %{media_item: media_item} do
      assert {:ok, updated_media_item} = MediaDownloader.download_for_media_item(media_item)
      assert updated_media_item.title == "Pinchflat Example Video"
    end

    test "extracts the description", %{media_item: media_item} do
      assert {:ok, updated_media_item} = MediaDownloader.download_for_media_item(media_item)
      assert is_binary(updated_media_item.description)
    end

    test "extracts the media_filepath", %{media_item: media_item} do
      assert media_item.media_filepath == nil
      assert {:ok, updated_media_item} = MediaDownloader.download_for_media_item(media_item)
      assert String.ends_with?(updated_media_item.media_filepath, ".mkv")
    end

    test "extracts the subtitle_filepaths", %{media_item: media_item} do
      assert media_item.subtitle_filepaths == []
      assert {:ok, updated_media_item} = MediaDownloader.download_for_media_item(media_item)
      assert [["de", _], ["en", _] | _rest] = updated_media_item.subtitle_filepaths
    end

    test "extracts the duration_seconds", %{media_item: media_item} do
      assert media_item.duration_seconds == nil
      assert {:ok, updated_media_item} = MediaDownloader.download_for_media_item(media_item)
      assert is_integer(updated_media_item.duration_seconds)
    end

    test "extracts the thumbnail_filepath", %{media_item: media_item} do
      expect(YtDlpRunnerMock, :run, 1, fn _url, :download, _opts, _ot, _addl ->
        metadata = render_parsed_metadata(:media_metadata)

        thumbnail_filepath =
          metadata["thumbnails"]
          |> Enum.reverse()
          |> Enum.find_value(fn attrs -> attrs["filepath"] end)
          |> String.split(~r{\.}, include_captures: true)
          |> List.insert_at(-3, "-thumb")
          |> Enum.join()

        :ok = File.cp(thumbnail_filepath_fixture(), thumbnail_filepath)

        {:ok, Phoenix.json_library().encode!(metadata)}
      end)

      expect(YtDlpRunnerMock, :run, 1, fn _url, :download_thumbnail, _opts, _ot, _addl_args -> {:ok, ""} end)

      assert media_item.thumbnail_filepath == nil
      assert {:ok, updated_media_item} = MediaDownloader.download_for_media_item(media_item)
      assert String.ends_with?(updated_media_item.thumbnail_filepath, ".webp")

      File.rm(updated_media_item.thumbnail_filepath)
    end

    test "extracts the metadata_filepath", %{media_item: media_item} do
      expect(YtDlpRunnerMock, :run, 1, fn _url, :download, _opts, _ot, _addl ->
        metadata = render_parsed_metadata(:media_metadata)

        infojson_filepath = metadata["infojson_filename"]
        :ok = File.cp(infojson_filepath_fixture(), infojson_filepath)

        {:ok, Phoenix.json_library().encode!(metadata)}
      end)

      expect(YtDlpRunnerMock, :run, 1, fn _url, :download_thumbnail, _opts, _ot, _addl_args -> {:ok, ""} end)

      assert media_item.metadata_filepath == nil
      assert {:ok, updated_media_item} = MediaDownloader.download_for_media_item(media_item)
      assert String.ends_with?(updated_media_item.metadata_filepath, ".info.json")

      File.rm(updated_media_item.metadata_filepath)
    end
  end

  describe "download_for_media_item/3 when testing NFO generation" do
    setup do
      stub(YtDlpRunnerMock, :run, fn
        _url, :download, _opts, _ot, _addl -> {:ok, render_metadata(:media_metadata)}
        _url, :download_thumbnail, _opts, _ot, _addl -> {:ok, ""}
      end)

      :ok
    end

    test "generates an NFO file if the source is set to download NFOs" do
      profile = media_profile_fixture(%{download_nfo: true})
      source = source_fixture(%{media_profile_id: profile.id})
      media_item = media_item_fixture(%{source_id: source.id})

      assert {:ok, updated_media_item} = MediaDownloader.download_for_media_item(media_item)

      assert String.ends_with?(updated_media_item.nfo_filepath, ".nfo")
      assert File.exists?(updated_media_item.nfo_filepath)

      File.rm!(updated_media_item.nfo_filepath)
    end

    test "does not generate an NFO file if the source is set to not download NFOs" do
      profile = media_profile_fixture(%{download_nfo: false})
      source = source_fixture(%{media_profile_id: profile.id})
      media_item = media_item_fixture(%{source_id: source.id})

      assert {:ok, updated_media_item} = MediaDownloader.download_for_media_item(media_item)

      assert updated_media_item.nfo_filepath == nil
    end
  end
end
