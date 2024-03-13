defmodule Pinchflat.Metadata.NfoBuilderTest do
  use Pinchflat.DataCase

  alias Pinchflat.Metadata.NfoBuilder

  setup do
    json_filepath =
      Path.join([
        File.cwd!(),
        "test",
        "support",
        "files",
        "media_metadata.json"
      ])

    {:ok, file_body} = File.read(json_filepath)
    {:ok, parsed_json} = Phoenix.json_library().decode(file_body)

    {:ok, %{metadata: parsed_json}}
  end

  describe "build_and_store_for_media_item/1" do
    test "returns the filepath", %{metadata: metadata} do
      result = NfoBuilder.build_and_store_for_media_item(metadata)

      assert File.exists?(result)

      File.rm!(result)
    end

    test "builds filepath based on media location", %{metadata: metadata} do
      result = NfoBuilder.build_and_store_for_media_item(metadata)

      assert String.contains?(result, Path.rootname(metadata["filepath"]))
      assert String.ends_with?(result, ".nfo")

      File.rm!(result)
    end

    test "builds an NFO file", %{metadata: metadata} do
      result = NfoBuilder.build_and_store_for_media_item(metadata)
      nfo = File.read!(result)

      assert String.contains?(nfo, ~S(<?xml version="1.0" encoding="UTF-8" standalone="yes" ?>))
      assert String.contains?(nfo, "<title>#{metadata["title"]}</title>")

      File.rm!(result)
    end
  end
end
