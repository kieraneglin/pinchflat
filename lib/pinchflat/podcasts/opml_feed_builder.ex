defmodule Pinchflat.Podcasts.OpmlFeedBuilder do
  @moduledoc """
  Methods for building an OPML feed for a list of sources.
  """

  import Pinchflat.Utils.XmlUtils, only: [safe: 1]

  alias PinchflatWeb.Router.Helpers, as: Routes

  @doc """
  Builds an OPML feed for a given list of sources.

  Returns an XML document as a string.
  """
  def build(url_base, sources) do
    sources_xml =
      Enum.map(
        sources,
        &"""
        <outline type="rss" text="#{safe(&1.custom_name)}" xmlUrl="#{safe(source_route(url_base, &1))}" />
        """
      )

    """
    <?xml version="1.0" encoding="UTF-8"?>
    <opml version="2.0">
    <head>
    <title>All Sources</title>
    </head>
    <body>
      #{Enum.join(sources_xml, "\n")}
    </body>
    </opml>
    """
  end

  defp source_route(url_base, source) do
    Path.join(url_base, "#{Routes.podcast_path(PinchflatWeb.Endpoint, :rss_feed, source.uuid)}.xml")
  end
end
