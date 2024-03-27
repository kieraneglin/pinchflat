defmodule Pinchflat.Podcasts.RssFeedBuilder do
  @moduledoc """
  Methods for building an RSS feed for a source and its media items.
  """

  @datetime_format "%a, %d %b %Y %H:%M:%S %z"

  alias Pinchflat.Utils.DatetimeUtils
  alias Pinchflat.Podcasts.PodcastHelpers
  alias PinchflatWeb.Router.Helpers, as: Routes

  @doc """
  Builds an RSS feed for a given source and its media items.
  Only MediaItems that have been persisted will be included in the feed.

  ## Options:
    - `:limit` - The maximum number of media items to include in the feed. Defaults to 300.

  Returns an XML document as a string.
  """
  def build(source, opts \\ []) do
    limit = Keyword.get(opts, :limit, 300)
    url_base = Keyword.get(opts, :url_base, PinchflatWeb.Endpoint.url())

    media_items = PodcastHelpers.persisted_media_items_for(source, limit: limit)
    build_source_xml(source, media_items, url_base)
  end

  defp build_source_xml(source, media_items, url_base) do
    media_item_xml = Enum.map(media_items, &build_media_item_xml(source, &1, url_base))
    # "caching" the image path since it requires some DB calls and is used twice
    feed_image_path = feed_image_path(url_base, source, media_items)

    # Useful: resources:
    #   - https://validator.w3.org/feed/#validate_by_input
    #   - https://github.com/Podcastindex-org/podcast-namespace/blob/main/docs/1.0.md
    #   - https://podba.se/validate
    """
    <?xml version="1.0" encoding="UTF-8"?>
    <rss version="2.0"
      xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd"
      xmlns:podcast="https://podcastindex.org/namespace/1.0"
      xmlns:atom="http://www.w3.org/2005/Atom">
      <channel>
        <title>#{safe(source.custom_name)}</title>
        <link>#{source.original_url}</link>
        <description>#{safe(source.description)}</description>
        <category>TV &amp; Film</category>
        <generator>Generated by Pinchflat</generator>
        <language>en-us</language>
        <lastBuildDate>#{Calendar.strftime(source.updated_at, @datetime_format)}</lastBuildDate>
        <pubDate>#{Calendar.strftime(source.inserted_at, @datetime_format)}</pubDate>
        <atom:link href="#{generate_self_link(url_base, source)}" rel="self" type="application/rss+xml" />
        <podcast:locked>yes</podcast:locked>
        <podcast:guid>#{source.uuid}</podcast:guid>
        <image>
          <url>#{feed_image_path}</url>
          <title>#{safe(source.custom_name)}</title>
          <link>#{source.original_url}</link>
        </image>
        <itunes:author>#{safe(source.custom_name)}</itunes:author>
        <itunes:subtitle>#{safe(source.custom_name)}</itunes:subtitle>
        <itunes:block>yes</itunes:block>
        <itunes:image href="#{feed_image_path}"></itunes:image>
        <itunes:explicit>false</itunes:explicit>
        <itunes:category text="TV &amp; Film"></itunes:category>

        #{Enum.join(media_item_xml, "\n")}

      </channel>
    </rss>
    """
  end

  defp build_media_item_xml(source, media_item, url_base) do
    """
    <item>
      <guid isPermaLink="false">#{media_item.uuid}</guid>
      <title>#{safe(media_item.title)}</title>
      <link>#{media_item.original_url}</link>
      <description>#{safe(media_item.description)}</description>
      <pubDate>#{generate_upload_date(media_item)}</pubDate>
      <enclosure
        url="#{media_stream_path(url_base, media_item)}"
        length="#{media_item.media_size_bytes}"
        type="#{MIME.from_path(media_item.media_filepath)}"
      />
      <itunes:author>#{safe(source.custom_name)}</itunes:author>
      <itunes:subtitle>#{safe(media_item.title)}</itunes:subtitle>
      <itunes:summary><![CDATA[#{media_item.description}]]></itunes:summary>
      <itunes:explicit>false</itunes:explicit>
    </item>
    """
  end

  defp safe(nil), do: ""

  defp safe(value) do
    value
    |> Phoenix.HTML.html_escape()
    |> Phoenix.HTML.safe_to_string()
  end

  defp generate_self_link(url_base, source) do
    Path.join(url_base, "#{podcast_route(:rss_feed, source.uuid)}.xml")
  end

  defp media_stream_path(url_base, media_item) do
    extension = Path.extname(media_item.media_filepath)

    Path.join(url_base, "#{media_route(:stream, media_item.uuid)}#{extension}")
  end

  defp feed_image_path(url_base, source, media_items) do
    case PodcastHelpers.select_cover_image(source, media_items) do
      {:error, _} ->
        ""

      {:ok, filepath} ->
        extension = Path.extname(filepath)
        Path.join(url_base, "#{podcast_route(:feed_image, source.uuid)}#{extension}")
    end
  end

  defp generate_upload_date(media_item) do
    media_item.upload_date
    |> DatetimeUtils.date_to_datetime()
    |> Calendar.strftime(@datetime_format)
  end

  defp podcast_route(action, params) do
    Routes.podcast_path(PinchflatWeb.Endpoint, action, params)
  end

  defp media_route(action, params) do
    Routes.media_item_path(PinchflatWeb.Endpoint, action, params)
  end
end
