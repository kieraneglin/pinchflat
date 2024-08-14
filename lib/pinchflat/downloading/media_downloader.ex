defmodule Pinchflat.Downloading.MediaDownloader do
  @moduledoc """
  This is the integration layer for actually downloading media.
  It takes into account the media profile's settings in order
  to download the media with the desired options.
  """

  require Logger

  alias Pinchflat.Repo
  alias Pinchflat.Media
  alias Pinchflat.Media.MediaItem
  alias Pinchflat.Metadata.NfoBuilder
  alias Pinchflat.Metadata.MetadataParser
  alias Pinchflat.Metadata.MetadataFileHelpers
  alias Pinchflat.Utils.FilesystemUtils
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
  def download_for_media_item(%MediaItem{} = media_item, override_opts \\ []) do
    output_filepath = FilesystemUtils.generate_metadata_tmpfile(:json)
    media_with_preloads = Repo.preload(media_item, [:metadata, source: :media_profile])

    case download_with_options(media_item.original_url, media_with_preloads, output_filepath, override_opts) do
      {:ok, parsed_json} ->
        update_media_item_from_parsed_json(media_with_preloads, parsed_json)

      {:error, message, _exit_code} ->
        Logger.error("yt-dlp download error for media item ##{media_with_preloads.id}: #{inspect(message)}")

        if String.contains?(to_string(message), recoverable_errors()) do
          attempt_update_media_item(media_with_preloads, output_filepath)

          {:recovered, message}
        else
          {:error, message}
        end

      err ->
        Logger.error("Unknown error downloading media item ##{media_with_preloads.id}: #{inspect(err)}")

        {:error, "Unknown error: #{inspect(err)}"}
    end
  end

  defp attempt_update_media_item(media_with_preloads, output_filepath) do
    with {:ok, contents} <- File.read(output_filepath),
         {:ok, parsed_json} <- Phoenix.json_library().decode(contents) do
      Logger.info("""
      Recovery from yt-dlp error seems possible. Updating media item ##{media_with_preloads.id}
      with parsed JSON from partial download attempt. Full download will be re-attemted in future
      anyway
      """)

      update_media_item_from_parsed_json(media_with_preloads, parsed_json)
    else
      err ->
        Logger.error("Unable to recover error for media item ##{media_with_preloads.id}: #{inspect(err)}")

        {:error, :retry_failed}
    end
  end

  defp update_media_item_from_parsed_json(media_with_preloads, parsed_json) do
    parsed_attrs =
      parsed_json
      |> MetadataParser.parse_for_media_item()
      |> Map.merge(%{
        media_downloaded_at: DateTime.utc_now(),
        culled_at: nil,
        nfo_filepath: determine_nfo_filepath(media_with_preloads, parsed_json),
        metadata: %{
          # IDEA: might be worth kicking off a job for this since thumbnail fetching
          # could fail and I want to handle that in isolation
          metadata_filepath: MetadataFileHelpers.compress_and_store_metadata_for(media_with_preloads, parsed_json),
          thumbnail_filepath: MetadataFileHelpers.download_and_store_thumbnail_for(media_with_preloads)
        }
      })

    # Don't forgor to use preloaded associations or updates to
    # associations won't work!
    Media.update_media_item(media_with_preloads, parsed_attrs)
  end

  defp determine_nfo_filepath(media_item, parsed_json) do
    if media_item.source.media_profile.download_nfo do
      filepath = Path.rootname(parsed_json["filepath"]) <> ".nfo"

      NfoBuilder.build_and_store_for_media_item(filepath, parsed_json)
    else
      nil
    end
  end

  defp download_with_options(url, item_with_preloads, output_filepath, override_opts) do
    {:ok, options} = DownloadOptionBuilder.build(item_with_preloads, override_opts)
    # TODO: test
    runner_opts = [output_filepath: output_filepath, use_cookies: item_with_preloads.source.use_cookies]

    YtDlpMedia.download(url, options, runner_opts)
  end

  defp recoverable_errors do
    [
      "Unable to communicate with SponsorBlock"
    ]
  end
end
