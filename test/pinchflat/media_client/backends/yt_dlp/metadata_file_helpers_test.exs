defmodule Pinchflat.MediaClient.Backends.YtDlp.MetadataFileHelpersTest do
  use Pinchflat.DataCase
  import Mox
  import Pinchflat.MediaFixtures

  alias Pinchflat.MediaClient.Backends.YtDlp.MetadataFileHelpers, as: Helpers

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
end
