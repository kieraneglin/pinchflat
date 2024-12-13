defmodule Pinchflat.Podcasts.OpmlFeedBuilderTest do
  use Pinchflat.DataCase

  import Pinchflat.SourcesFixtures

  alias Pinchflat.Podcasts.OpmlFeedBuilder

  setup do
    source = source_fixture()

    {:ok, source: source}
  end

  describe "build/2" do
    test "returns an XML document", %{source: source} do
      res = OpmlFeedBuilder.build("http://example.com", [source])

      assert String.contains?(res, ~s(<?xml version="1.0" encoding="UTF-8"?>))
    end

    test "escapes illegal characters" do
      source = source_fixture(%{custom_name: "A & B"})
      res = OpmlFeedBuilder.build("http://example.com", [source])

      assert String.contains?(res, ~s(A &amp; B))
    end

    test "build podcast link with URL base", %{source: source} do
      res = OpmlFeedBuilder.build("http://example.com", [source])

      assert String.contains?(res, ~s(http://example.com/sources/#{source.uuid}/feed.xml))
    end
  end
end
