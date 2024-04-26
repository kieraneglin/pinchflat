defmodule Pinchflat.Podcasts.RssFeedBuilderTest do
  use Pinchflat.DataCase

  import Pinchflat.MediaFixtures
  import Pinchflat.SourcesFixtures

  alias Pinchflat.Podcasts.RssFeedBuilder

  @datetime_format "%a, %d %b %Y %H:%M:%S %z"

  setup do
    source = source_fixture()

    {:ok, source: source}
  end

  describe "build/2" do
    test "returns an XML document", %{source: source} do
      res = RssFeedBuilder.build(source)

      assert String.contains?(res, ~s(<?xml version="1.0" encoding="UTF-8"?>))
    end

    test "escapes illegal characters" do
      source = source_fixture(%{custom_name: "A & B"})
      res = RssFeedBuilder.build(source)

      assert String.contains?(res, ~s(<title>A &amp; B</title>))
    end

    test "can optionally apply a limit to media items", %{source: source} do
      good_media = media_item_with_attachments(%{source_id: source.id})

      res = RssFeedBuilder.build(source, limit: 0)

      refute String.contains?(res, ~s(<title>#{good_media.title}</title>))
    end

    test "can optionally specify a URL base", %{source: source} do
      res = RssFeedBuilder.build(source, url_base: "http://example.com")

      assert String.contains?(res, ~s(http://example.com/sources/#{source.uuid}/feed.xml))
    end
  end

  describe "build/2 when testing source XML" do
    test "returns XML for static source attributes", %{source: source} do
      res = RssFeedBuilder.build(source)

      assert String.contains?(res, ~s(<title>#{source.custom_name}</title>))
      assert String.contains?(res, ~s(<link>#{source.original_url}</link>))
      assert String.contains?(res, ~s(<description>#{source.description}</description>))
      assert String.contains?(res, ~s(<itunes:author>#{source.custom_name}</itunes:author>))
      assert String.contains?(res, ~s(<itunes:subtitle>#{source.custom_name}</itunes:subtitle>))
      assert String.contains?(res, ~s(<description>#{source.description}</description>))
      assert String.contains?(res, ~s(<podcast:guid>#{source.uuid}</podcast:guid>))
    end

    test "returns the lastBuildDate and pubDate based off the source's timestamps", %{source: source} do
      res = RssFeedBuilder.build(source)

      assert String.contains?(res, ~s(<lastBuildDate>#{format_date(source.updated_at)}</lastBuildDate>))
      assert String.contains?(res, ~s(<pubDate>#{format_date(source.inserted_at)}</pubDate>))
    end

    test "returns a self-link", %{source: source} do
      res = RssFeedBuilder.build(source)

      assert String.contains?(
               res,
               ~s(<atom:link href="http://localhost:8945/sources/#{source.uuid}/feed.xml" rel="self" type="application/rss+xml" />)
             )
    end

    test "returns a link to the feed image" do
      source = source_with_metadata_attachments()

      res = RssFeedBuilder.build(source)
      [_before, image_block, _after] = String.split(res, ~r(</?image>))

      assert String.contains?(image_block, ~s(<url>http://localhost:8945/sources/#{source.uuid}/feed_image.jpg</url>))
      assert String.contains?(image_block, ~s(<title>#{source.custom_name}</title>))
      assert String.contains?(image_block, ~s(<link>#{source.original_url}</link>))

      assert String.contains?(
               res,
               ~s(<itunes:image href="http://localhost:8945/sources/#{source.uuid}/feed_image.jpg"></itunes:image>)
             )
    end
  end

  describe "build/2 when testing media XML" do
    test "only includes media persisted to disk", %{source: source} do
      good_media = media_item_with_attachments(%{source_id: source.id})
      bad_media = media_item_fixture(%{source_id: source.id, media_filepath: "/tmp/existing_file.mp3"})
      pending_media = media_item_fixture(%{source_id: source.id, media_filepath: nil})

      res = RssFeedBuilder.build(source)

      assert String.contains?(res, ~s(<title>#{good_media.title}</title>))
      refute String.contains?(res, ~s(<title>#{bad_media.title}</title>))
      refute String.contains?(res, ~s(<title>#{pending_media.title}</title>))
    end

    test "returns XML for static media attributes", %{source: source} do
      media_item = media_item_with_attachments(%{source_id: source.id})

      res = RssFeedBuilder.build(source)
      [_before, item_xml, _after] = String.split(res, ~r(</?item>))

      assert String.contains?(item_xml, ~s(<guid isPermaLink="false">#{media_item.uuid}</guid>))
      assert String.contains?(item_xml, ~s(<title>#{media_item.title}</title>))
      assert String.contains?(item_xml, ~s(<link>#{media_item.original_url}</link>))
      assert String.contains?(item_xml, ~s(<description>#{media_item.description}</description>))
      assert String.contains?(item_xml, ~s(<itunes:author>#{source.custom_name}</itunes:author>))
      assert String.contains?(item_xml, ~s(<itunes:subtitle>#{media_item.title}</itunes:subtitle>))
      assert String.contains?(item_xml, ~s(<itunes:summary><![CDATA[#{media_item.description}]]></itunes:summary>))
    end

    test "returns pubDate based off the media's upload_date", %{source: source} do
      media_item_with_attachments(%{source_id: source.id, upload_date: ~D[2020-01-01]})

      res = RssFeedBuilder.build(source)
      [_before, item_xml, _after] = String.split(res, ~r(</?item>))

      assert String.contains?(item_xml, ~s(<pubDate>Wed, 01 Jan 2020 00:00:00 +0000</pubDate>))
    end

    test "returns an enclosure tag with the media's stream URL", %{source: source} do
      media_item = media_item_with_attachments(%{source_id: source.id, media_size_bytes: 1234})

      res = RssFeedBuilder.build(source)
      [_before, item_xml, _after] = String.split(res, ~r(</?item>))

      assert String.contains?(item_xml, ~s(<enclosure))
      assert String.contains?(item_xml, ~s(url="http://localhost:8945/media/#{media_item.uuid}/stream.mp4"))
      assert String.contains?(item_xml, ~s(length="1234"))
      assert String.contains?(item_xml, ~s(type="video/mp4"))
    end

    test "returns image tags if the media has a thumbnail", %{source: source} do
      media_item = media_item_with_attachments(%{source_id: source.id, media_size_bytes: 1234})

      res = RssFeedBuilder.build(source)
      [_before, item_xml, _after] = String.split(res, ~r(</?item>))

      assert String.contains?(
               item_xml,
               ~s(<itunes:image href="http://localhost:8945/media/#{media_item.uuid}/episode_image.jpg"></itunes:image>)
             )

      assert String.contains?(
               item_xml,
               ~s(<podcast:images srcset="http://localhost:8945/media/#{media_item.uuid}/episode_image.jpg" />)
             )
    end

    test "does not return image tags if the media does not have a thumbnail", %{source: source} do
      media_item = media_item_with_attachments(%{source_id: source.id})
      File.rm!(media_item.thumbnail_filepath)

      res = RssFeedBuilder.build(source)
      [_before, item_xml, _after] = String.split(res, ~r(</?item>))

      refute String.contains?(item_xml, ~s(itunes:image))
      refute String.contains?(item_xml, ~s(podcast:images))
    end
  end

  defp format_date(date) do
    Calendar.strftime(date, @datetime_format)
  end
end
