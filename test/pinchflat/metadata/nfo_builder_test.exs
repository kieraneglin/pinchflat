defmodule Pinchflat.Metadata.NfoBuilderTest do
  use Pinchflat.DataCase

  alias Pinchflat.Metadata.NfoBuilder

  setup do
    {:ok, %{metadata: render_parsed_metadata(:media_metadata)}}
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
