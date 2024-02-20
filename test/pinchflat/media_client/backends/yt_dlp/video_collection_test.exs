defmodule Pinchflat.MediaClient.Backends.YtDlp.VideoCollectionTest do
  use ExUnit.Case, async: true
  import Mox
  import Pinchflat.SourcesFixtures

  alias Pinchflat.MediaClient.Backends.YtDlp.VideoCollection

  @channel_url "https://www.youtube.com/c/TheUselessTrials"

  setup :verify_on_exit!

  describe "get_media_attributes/2" do
    test "returns a list of video attributes with no blank elements" do
      expect(YtDlpRunnerMock, :run, fn _url, _opts, _ot -> {:ok, source_attributes_return_fixture() <> "\n\n"} end)

      assert {:ok, [%{"id" => "video1"}, %{"id" => "video2"}, %{"id" => "video3"}]} =
               VideoCollection.get_media_attributes(@channel_url)
    end

    test "it passes the expected default args" do
      expect(YtDlpRunnerMock, :run, fn _url, opts, ot ->
        assert opts == [:simulate, :skip_download]
        assert ot == "%(.{id,title,was_live,original_url,description})j"

        {:ok, ""}
      end)

      assert {:ok, _} = VideoCollection.get_media_attributes(@channel_url)
    end

    test "it passes the expected custom args" do
      expect(YtDlpRunnerMock, :run, fn _url, opts, _ot ->
        assert opts == [:custom_arg, :simulate, :skip_download]

        {:ok, ""}
      end)

      assert {:ok, _} = VideoCollection.get_media_attributes(@channel_url, [:custom_arg])
    end

    test "returns the error straight through when the command fails" do
      expect(YtDlpRunnerMock, :run, fn _url, _opts, _ot -> {:error, "Big issue", 1} end)

      assert {:error, "Big issue", 1} = VideoCollection.get_media_attributes(@channel_url)
    end
  end

  describe "get_source_details/1" do
    test "it returns a map with data on success" do
      expect(YtDlpRunnerMock, :run, fn _url, _opts, _ot ->
        Phoenix.json_library().encode(%{
          channel: "TheUselessTrials",
          channel_id: "UCQH2",
          playlist_id: "PLQH2",
          playlist_title: "TheUselessTrials - Videos"
        })
      end)

      assert {:ok, res} = VideoCollection.get_source_details(@channel_url)

      assert %{
               channel_id: "UCQH2",
               channel_name: "TheUselessTrials",
               playlist_id: "PLQH2",
               playlist_name: "TheUselessTrials - Videos"
             } = res
    end

    test "it passes the expected args to the backend runner" do
      expect(YtDlpRunnerMock, :run, fn @channel_url, opts, ot ->
        assert opts == [:simulate, :skip_download, playlist_end: 1]
        assert ot == "%(.{channel,channel_id,playlist_id,playlist_title})j"

        {:ok, "{}"}
      end)

      assert {:ok, _} = VideoCollection.get_source_details(@channel_url)
    end

    test "it returns an error if the runner returns an error" do
      expect(YtDlpRunnerMock, :run, fn _url, _opts, _ot -> {:error, "Big issue", 1} end)

      assert {:error, "Big issue", 1} = VideoCollection.get_source_details(@channel_url)
    end

    test "it returns an error if the output is not JSON" do
      expect(YtDlpRunnerMock, :run, fn _url, _opts, _ot -> {:ok, "Not JSON"} end)

      assert {:error, %Jason.DecodeError{}} = VideoCollection.get_source_details(@channel_url)
    end
  end
end
