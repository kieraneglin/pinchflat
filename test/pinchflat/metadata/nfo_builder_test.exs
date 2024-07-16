defmodule Pinchflat.Metadata.NfoBuilderTest do
  use Pinchflat.DataCase

  alias Pinchflat.Metadata.NfoBuilder
  alias Pinchflat.Utils.FilesystemUtils

  setup do
    filepath = FilesystemUtils.generate_metadata_tmpfile(:nfo)

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

    test "uses the season and episode number from the filepath if it can be determined" do
      metadata = %{
        "title" => "title",
        "uploader" => "uploader",
        "id" => "id",
        "description" => "description",
        "upload_date" => "20210101"
      }

      tmpfile_directory = Application.get_env(:pinchflat, :tmpfile_directory)
      filepath = Path.join([tmpfile_directory, "foo/s0123e456.nfo"])

      result = NfoBuilder.build_and_store_for_media_item(filepath, metadata)
      nfo = File.read!(result)

      assert String.contains?(nfo, "<season>0123</season>")
      assert String.contains?(nfo, "<episode>456</episode>")

      File.rm!(filepath)
    end

    test "uses the upload date if the season and episode number can't be determined", %{filepath: filepath} do
      metadata = %{
        "title" => "title",
        "uploader" => "uploader",
        "id" => "id",
        "description" => "description",
        "upload_date" => "20210101"
      }

      result = NfoBuilder.build_and_store_for_media_item(filepath, metadata)
      nfo = File.read!(result)

      assert String.contains?(nfo, "<season>2021</season>")
      assert String.contains?(nfo, "<episode>0101</episode>")
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
