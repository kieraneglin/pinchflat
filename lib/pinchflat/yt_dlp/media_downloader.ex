defmodule Pinchflat.MediaClient.MediaDownloader do
  @moduledoc """
  This is the integration layer for actually downloading media.
  It takes into account the media profile's settings in order
  to download the media with the desired options.
  """

  alias Pinchflat.Repo
  alias Pinchflat.Media
  alias Pinchflat.Media.MediaItem

  alias Pinchflat.YtDlp.Backend.Media, as: YtDlpMedia
  alias Pinchflat.Downloading.DownloadOptionBuilder, as: YtDlpDownloadOptionBuilder
  alias Pinchflat.Metadata.MetadataParser, as: YtDlpMetadataParser
  alias Pinchflat.Metadata.MetadataFileHelpers, as: YtDlpMetadataHelpers

  @doc """
  Downloads media for a media item, updating the media item based on the metadata
  returned by yt-dlp. Also saves the entire metadata response to the associated
  media_metadata record.

  NOTE: related methods (like the download worker) won't download if the media item's source
  is set to not download media. However, I'm not enforcing that here since I need this for testing.
  This may change in the future but I'm not stressed.

  Returns {:ok, %MediaItem{}} | {:error, any, ...any}
  """
  def download_for_media_item(%MediaItem{} = media_item) do
    item_with_preloads = Repo.preload(media_item, [:metadata, source: :media_profile])

    case download_with_options(media_item.original_url, item_with_preloads) do
      {:ok, parsed_json} ->
        {parser, helpers} = {YtDlpMetadataParser, YtDlpMetadataHelpers}

        parsed_attrs =
          parsed_json
          |> parser.parse_for_media_item()
          |> Map.merge(%{
            media_downloaded_at: DateTime.utc_now(),
            metadata: %{
              metadata_filepath: helpers.compress_and_store_metadata_for(media_item, parsed_json),
              thumbnail_filepath: helpers.download_and_store_thumbnail_for(media_item, parsed_json)
            }
          })

        # Don't forgor to use preloaded associations or updates to
        # associations won't work!
        Media.update_media_item(item_with_preloads, parsed_attrs)

      err ->
        err
    end
  end

  # def download_for_source(source, url) do
  #   # Create MI from source and URL
  #   media_item = nil
  # end

  defp download_with_options(url, item_with_preloads) do
    {:ok, options} = YtDlpDownloadOptionBuilder.build(item_with_preloads)

    YtDlpMedia.download(url, options)
  end
end
