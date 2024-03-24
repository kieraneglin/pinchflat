defmodule Pinchflat.Podcasts.RssFeedBuilder do
  @datetime_format "%a, %d %b %Y %H:%M:%S %z"

  # TODO: test
  # TODO: only MIs that are confirmed to exist on-disk should be provided
  def build(source, media_items) do
    media_item_xml = Enum.map(media_items, &build_media_item_xml(source, &1))

    build_source_xml(source, media_item_xml)
  end

  defp build_source_xml(source, media_item_xml) do
    # Useful: resources:
    #   - https://validator.w3.org/feed/#validate_by_input
    #   - https://github.com/Podcastindex-org/podcast-namespace/blob/main/docs/1.0.md
    #   - https://podba.se/validate
    #
    # - Add real <description>
    # - Serve proper images instead of the placeholders
    """
    <?xml version="1.0" encoding="UTF-8"?>
    <rss version="2.0"
      xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd"
      xmlns:podcast="https://podcastindex.org/namespace/1.0"
      xmlns:atom="http://www.w3.org/2005/Atom">
      <channel>
        <title>#{source.custom_name}</title>
        <link>#{source.original_url}</link>
        <description>#{source.custom_name}</description>
        <category>TV &amp; Film</category>
        <generator>Generated by Pinchflat</generator>
        <language>en-us</language>
        <lastBuildDate>#{Calendar.strftime(DateTime.utc_now(), @datetime_format)}</lastBuildDate>
        <pubDate>#{Calendar.strftime(source.inserted_at, @datetime_format)}</pubDate>
        <atom:link href="#{generate_self_link(source)}" rel="self" type="application/rss+xml" />
        <podcast:locked>yes</podcast:locked>
        <podcast:guid>#{source.uuid}</podcast:guid>
        <image>
          <url>#{generate_source_image_path(source)}</url>
          <title>#{source.custom_name}</title>
          <link>#{source.original_url}</link>
        </image>
        <itunes:author>#{source.custom_name}</itunes:author>
        <itunes:subtitle>#{source.custom_name}</itunes:subtitle>
        <itunes:block>yes</itunes:block>
        <itunes:image href="#{generate_source_image_path(source)}"></itunes:image>
        <itunes:explicit>false</itunes:explicit>
        <itunes:category text="TV &amp; Film"></itunes:category>

        #{Enum.join(media_item_xml, "\n")}

      </channel>
    </rss>
    """
  end

  defp build_media_item_xml(source, media_item) do
    """
    <item>
      <guid isPermaLink="false">#{media_item.uuid}</guid>
      <title>#{media_item.title}</title>
      <link>#{media_item.original_url}</link>
      <description>#{media_item.description}</description>
      <pubDate>#{generate_upload_date(media_item)}</pubDate>
      <enclosure
        url="#{generate_media_stream_path(media_item)}"
        length="#{media_item.media_size_bytes}"
        type="#{determine_content_type(media_item)}">
      </enclosure>
      <itunes:author>#{source.custom_name}</itunes:author>
      <itunes:subtitle>#{media_item.title}</itunes:subtitle>
      <itunes:summary><![CDATA[#{media_item.description}]]></itunes:summary>
      <itunes:explicit>false</itunes:explicit>
    </item>
    """
  end

  defp generate_self_link(source) do
    "#{url_base()}/sources/#{source.uuid}/feed.xml"
  end

  defp generate_media_stream_path(media_item) do
    extension = Path.extname(media_item.media_filepath)

    "#{url_base()}/media/#{media_item.uuid}/stream#{extension}"
  end

  # TODO: add extension maybe. maybe refactor controller to handle this
  defp generate_source_image_path(source) do
    "#{url_base()}/sources/#{source.uuid}/feed_image"
  end

  defp generate_upload_date(media_item) do
    media_item.upload_date
    |> Date.to_gregorian_days()
    |> Kernel.*(86400)
    |> DateTime.from_gregorian_seconds()
    |> Calendar.strftime(@datetime_format)
  end

  defp determine_content_type(media_item) do
    MIME.from_path(media_item.media_filepath)
  end

  defp url_base do
    Application.get_env(:pinchflat, :url_base)
  end
end
