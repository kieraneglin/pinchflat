defmodule Pinchflat.Metadata.NfoBuilderTest do
  use Pinchflat.DataCase

  alias Pinchflat.Metadata.NfoBuilder
  alias Pinchflat.Filesystem.FilesystemHelpers

  setup do
    filepath = FilesystemHelpers.generate_metadata_tmpfile(:json)

    on_exit(fn -> File.rm!(filepath) end)

    {:ok,
     %{
       metadata: render_parsed_metadata(:media_metadata),
       filepath: filepath
     }}
  end

  describe "build_and_store_for_media_item/2" do
    test "returns the filepath", %{metadata: metadata, filepath: filepath} do
      result = NfoBuilder.build_and_store_for_media_item(filepath, metadata)

      assert File.exists?(result)
    end

    test "builds an NFO file", %{metadata: metadata, filepath: filepath} do
      result = NfoBuilder.build_and_store_for_media_item(filepath, metadata)
      nfo = File.read!(result)

      assert String.contains?(nfo, ~S(<?xml version="1.0" encoding="UTF-8" standalone="yes" ?>))
      assert String.contains?(nfo, "<title>#{metadata["title"]}</title>")
    end

    test "escapes invalid characters", %{filepath: filepath} do
      metadata = %{
        "title" => "hello' & <world>",
        "uploader" => "uploader",
        "id" => "id",
        "description" => "description",
        "upload_date" => "20210101"
      }

      result = NfoBuilder.build_and_store_for_media_item(filepath, metadata)
      nfo = File.read!(result)

      assert String.contains?(nfo, "hello&#39; &amp; &lt;world&gt;")
    end
  end

  describe "build_and_store_for_source/2" do
    test "returns the filepath", %{metadata: metadata, filepath: filepath} do
      result = NfoBuilder.build_and_store_for_source(filepath, metadata)

      assert File.exists?(result)
    end

    test "builds an NFO file", %{metadata: metadata, filepath: filepath} do
      result = NfoBuilder.build_and_store_for_source(filepath, metadata)
      nfo = File.read!(result)

      assert String.contains?(nfo, ~S(<?xml version="1.0" encoding="UTF-8" standalone="yes" ?>))
      assert String.contains?(nfo, "<title>#{metadata["title"]}</title>")
    end

    test "escapes invalid characters", %{filepath: filepath} do
      metadata = %{
        "title" => "hello' & <world>",
        "description" => "description",
        "id" => "id"
      }

      result = NfoBuilder.build_and_store_for_source(filepath, metadata)
      nfo = File.read!(result)

      assert String.contains?(nfo, "hello&#39; &amp; &lt;world&gt;")
    end
  end
end
