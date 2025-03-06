defmodule Pinchflat.Downloading.MediaDownloader do
  @moduledoc """
  This is the integration layer for actually downloading media.
  It takes into account the media profile's settings in order
  to download the media with the desired options.
  """

  require Logger

  alias Pinchflat.Repo
  alias Pinchflat.Media
  alias Pinchflat.Sources
  alias Pinchflat.Media.MediaItem
  alias Pinchflat.Utils.StringUtils
  alias Pinchflat.Metadata.NfoBuilder
  alias Pinchflat.Metadata.MetadataParser
  alias Pinchflat.Metadata.MetadataFileHelpers
  alias Pinchflat.Utils.FilesystemUtils
  alias Pinchflat.Downloading.DownloadOptionBuilder

  alias Pinchflat.YtDlp.Media, as: YtDlpMedia

  @doc """
  Downloads media for a media item, updating the media item based on the metadata
  returned by yt-dlp. Encountered errors are saved to the Media Item record. Saves
  the entire metadata response to the associated media_metadata record.

  NOTE: related methods (like the download worker) won't download if Pthe media item's source
  is set to not download media. However, I'm not enforcing that here since I need this for testing.
  This may change in the future but I'm not stressed.

  Returns {:ok, %MediaItem{}} | {:error, atom(), String.t()} | {:recovered, %MediaItem{}, String.t()}
  """
  def download_for_media_item(%MediaItem{} = media_item, override_opts \\ []) do
    case attempt_download_and_update_for_media_item(media_item, override_opts) do
      {:ok, media_item} ->
        # Returns {:ok, %MediaItem{}}
        Media.update_media_item(media_item, %{last_error: nil})

      {:error, error_atom, message} ->
        Media.update_media_item(media_item, %{last_error: StringUtils.wrap_string(message)})

        {:error, error_atom, message}

      {:recovered, media_item, message} ->
        {:ok, updated_media_item} = Media.update_media_item(media_item, %{last_error: StringUtils.wrap_string(message)})

        {:recovered, updated_media_item, message}
    end
  end

  # Looks complicated, but here's the key points:
  # - download_with_options runs a pre-check to see if the media item is suitable for download.
  # - If the media item fails the precheck, it returns {:error, :unsuitable_for_download, message}
  #   - However, if the precheck fails in a way that we think can be fixed by using cookies, we retry with cookies
  #     and return the result of that
  # - If the precheck passes but the download fails, it normally returns {:error, :download_failed, message}
  #   - However, there are some errors we can recover from (eg: failure to communicate with SponsorBlock).
  #     In this case, we attempt the download anyway and update the media item with what details we do have.
  #     This case returns {:recovered, updated_media_item, message}
  #   - If we attempt a retry but it fails, we return {:error, :unrecoverable, message}
  # - If there is an unknown error unrelated to the above, we return {:error, :unknown, message}
  # - Finally, if there is no error, we update the media item with the parsed JSON and return {:ok, updated_media_item}
  #
  # Restated, here are the return values for each case:
  # - On success: {:ok, updated_media_item}
  # - On initial failure but successfully recovered: {:recovered, updated_media_item, message}
  # - On error: {:error, error_atom, message} where error_atom is one of:
  #   - `:unsuitable_for_download` if the media item fails the precheck
  #   - `:unrecoverable` if there was an initial failure and the recovery attempt failed
  #   - `:download_failed` for all other yt-dlp-related downloading errors
  #   - `:unknown` for any other errors, including those not related to yt-dlp
  # - If we retry using cookies, all of the above return values apply. The cookie retry
  #   logic is handled transparently as far as the caller is concerned
  defp attempt_download_and_update_for_media_item(media_item, override_opts) do
    output_filepath = FilesystemUtils.generate_metadata_tmpfile(:json)
    media_with_preloads = Repo.preload(media_item, [:metadata, source: :media_profile])

    case download_with_options(media_item.original_url, media_with_preloads, output_filepath, override_opts) do
      {:ok, parsed_json} ->
        update_media_item_from_parsed_json(media_with_preloads, parsed_json)

      {:error, :unsuitable_for_download} ->
        message =
          "Media item ##{media_with_preloads.id} isn't suitable for download yet. May be an active or processing live stream"

        Logger.warning(message)

        {:error, :unsuitable_for_download, message}

      {:error, message, _exit_code} ->
        Logger.error("yt-dlp download error for media item ##{media_with_preloads.id}: #{inspect(message)}")

        if String.contains?(to_string(message), recoverable_errors()) do
          attempt_recovery_from_error(media_with_preloads, output_filepath, message)
        else
          {:error, :download_failed, message}
        end

      err ->
        Logger.error("Unknown error downloading media item ##{media_with_preloads.id}: #{inspect(err)}")

        {:error, :unknown, "Unknown error: #{inspect(err)}"}
    end
  end

  defp attempt_recovery_from_error(media_with_preloads, output_filepath, error_message) do
    with {:ok, contents} <- File.read(output_filepath),
         {:ok, parsed_json} <- Phoenix.json_library().decode(contents) do
      Logger.info("""
      Recovery from yt-dlp error seems possible. Updating media item ##{media_with_preloads.id}
      with parsed JSON from partial download attempt. Full download will be re-attemted in future
      anyway
      """)

      {:ok, updated_media_item} = update_media_item_from_parsed_json(media_with_preloads, parsed_json)
      {:recovered, updated_media_item, error_message}
    else
      err ->
        Logger.error("Unable to recover error for media item ##{media_with_preloads.id}: #{inspect(err)}")

        {:error, :unrecoverable, error_message}
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
    force_use_cookies = Keyword.get(override_opts, :force_use_cookies, false)
    source_uses_cookies = Sources.use_cookies?(item_with_preloads.source, :downloading)
    should_use_cookies = force_use_cookies || source_uses_cookies

    runner_opts = [output_filepath: output_filepath, use_cookies: should_use_cookies]

    case {YtDlpMedia.get_downloadable_status(url, use_cookies: should_use_cookies), should_use_cookies} do
      {{:ok, :downloadable}, _} ->
        YtDlpMedia.download(url, options, runner_opts)

      {{:ok, :ignorable}, _} ->
        {:error, :unsuitable_for_download}

      {{:error, _message, _exit_code} = err, false} ->
        # If there was an error and we don't have cookies, this method will retry with cookies
        # if doing so would help AND the source allows. Otherwise, it will return the error as-is
        maybe_retry_with_cookies(url, item_with_preloads, output_filepath, override_opts, err)

      # This gets hit if cookies are enabled which, importantly, also covers the case where we
      # retry a download with cookies and it fails again
      {{:error, message, exit_code}, true} ->
        {:error, message, exit_code}

      {err, _} ->
        err
    end
  end

  defp maybe_retry_with_cookies(url, item_with_preloads, output_filepath, override_opts, err) do
    {:error, message, _} = err
    source = item_with_preloads.source
    message_contains_cookie_error = String.contains?(to_string(message), recoverable_cookie_errors())

    if Sources.use_cookies?(source, :error_recovery) && message_contains_cookie_error do
      download_with_options(
        url,
        item_with_preloads,
        output_filepath,
        Keyword.put(override_opts, :force_use_cookies, true)
      )
    else
      err
    end
  end

  defp recoverable_errors do
    [
      "Unable to communicate with SponsorBlock"
    ]
  end

  defp recoverable_cookie_errors do
    [
      "Sign in to confirm",
      "This video is available to this channel's members"
    ]
  end
end
