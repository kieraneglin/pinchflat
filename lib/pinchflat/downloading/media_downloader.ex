defmodule Pinchflat.Downloading.MediaDownloader do
  @moduledoc """
  This is the integration layer for actually downloading media.
  It takes into account the media profile's settings in order
  to download the media with the desired options.
  """

  alias Pinchflat.Repo
  alias Pinchflat.Media
  alias Pinchflat.Media.MediaItem
  alias Pinchflat.Metadata.NfoBuilder
  alias Pinchflat.Metadata.MetadataParser
  alias Pinchflat.Metadata.MetadataFileHelpers
  alias Pinchflat.Downloading.DownloadOptionBuilder

  alias Pinchflat.YtDlp.Media, as: YtDlpMedia

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
        parsed_attrs =
          parsed_json
          |> MetadataParser.parse_for_media_item()
          |> Map.merge(%{
            media_downloaded_at: DateTime.utc_now(),
            nfo_filepath: determine_nfo_filepath(item_with_preloads, parsed_json),
            metadata: %{
              metadata_filepath: MetadataFileHelpers.compress_and_store_metadata_for(media_item, parsed_json),
              thumbnail_filepath: MetadataFileHelpers.download_and_store_thumbnail_for(media_item, parsed_json)
            }
          })

        # Don't forgor to use preloaded associations or updates to
        # associations won't work!
        Media.update_media_item(item_with_preloads, parsed_attrs)

      err ->
        err
    end
  end

  defp determine_nfo_filepath(media_item, parsed_json) do
    if media_item.source.media_profile.download_nfo do
      NfoBuilder.build_and_store_for_media_item(parsed_json)
    else
      nil
    end
  end

  defp download_with_options(url, item_with_preloads) do
    {:ok, options} = DownloadOptionBuilder.build(item_with_preloads)

    YtDlpMedia.download(url, options)
  end
end
