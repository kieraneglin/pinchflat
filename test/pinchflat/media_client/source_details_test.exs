defmodule Pinchflat.MediaClient.SourceDetailsTest do
  use Pinchflat.DataCase
  import Mox
  import Pinchflat.ProfilesFixtures
  import Pinchflat.MediaSourceFixtures

  alias Pinchflat.MediaClient.SourceDetails

  @channel_url "https://www.youtube.com/c/TheUselessTrials"

  setup :verify_on_exit!

  describe "get_source_details/2" do
    test "it passes the expected arguments to the backend" do
      expect(YtDlpRunnerMock, :run, fn @channel_url, opts, ot ->
        assert opts == [:simulate, :skip_download, playlist_end: 1]
        assert ot == "%(.{channel,channel_id,playlist_id,playlist_title})j"

        {:ok, "{}"}
      end)

      assert {:ok, _} = SourceDetails.get_source_details(@channel_url)
    end

    test "it returns a map composed of the returned data" do
      expect(YtDlpRunnerMock, :run, fn _url, _opts, _ot ->
        Phoenix.json_library().encode(%{
          channel: "TheUselessTrials",
          channel_id: "UCQH2",
          playlist_id: "PLQH2",
          playlist_title: "TheUselessTrials - Videos"
        })
      end)

      assert {:ok, res} = SourceDetails.get_source_details(@channel_url)

      assert %{
               channel_id: "UCQH2",
               channel_name: "TheUselessTrials",
               playlist_id: "PLQH2",
               playlist_name: "TheUselessTrials - Videos"
             } = res
    end
  end

  describe "get_media_attributes/2 when passed a string" do
    test "it passes the expected arguments to the backend" do
      expect(YtDlpRunnerMock, :run, fn @channel_url, opts, ot ->
        assert opts == [:simulate, :skip_download]
        assert ot == "%(.{id,title,was_live,original_url})j"

        {:ok, ""}
      end)

      assert {:ok, _} = SourceDetails.get_media_attributes(@channel_url)
    end

    test "it returns a list of maps" do
      expect(YtDlpRunnerMock, :run, fn _url, _opts, _ot ->
        {:ok, source_attributes_return_fixture()}
      end)

      assert {:ok, [%{}, %{}, %{}]} = SourceDetails.get_media_attributes(@channel_url)
    end
  end

  describe "get_media_attributes/2 when passed a Source record" do
    test "it calls the backend with the source's collection ID" do
      source = source_fixture()

      expect(YtDlpRunnerMock, :run, fn url, _opts, _ot ->
        assert source.collection_id == url
        {:ok, source_attributes_return_fixture()}
      end)

      assert {:ok, _} = SourceDetails.get_media_attributes(source)
    end

    test "it builds options based on the source's media profile" do
      expect(YtDlpRunnerMock, :run, fn _url, opts, _ot ->
        assert opts == [:simulate, :skip_download]
        {:ok, ""}
      end)

      media_profile =
        media_profile_fixture(
          shorts_behaviour: :include,
          livestream_behaviour: :exclude
        )

      source = source_fixture(media_profile_id: media_profile.id)
      assert {:ok, _} = SourceDetails.get_media_attributes(source)
    end
  end
end
