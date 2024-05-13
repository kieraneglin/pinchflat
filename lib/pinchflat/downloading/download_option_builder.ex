defmodule Pinchflat.Downloading.DownloadOptionBuilder do
  @moduledoc """
  Builds the options for yt-dlp to download media based on the given media profile.
  """

  alias Pinchflat.Sources
  alias Pinchflat.Sources.Source
  alias Pinchflat.Media.MediaItem
  alias Pinchflat.Downloading.OutputPathBuilder

  alias Pinchflat.Utils.FilesystemUtils, as: FSUtils

  @doc """
  Builds the options for yt-dlp to download media based on the given media's profile.

  Returns {:ok, [Keyword.t()]}
  """
  def build(%MediaItem{} = media_item_with_preloads, override_opts \\ []) do
    media_profile = media_item_with_preloads.source.media_profile

    built_options =
      default_options(override_opts) ++
        subtitle_options(media_profile) ++
        thumbnail_options(media_item_with_preloads) ++
        metadata_options(media_profile) ++
        quality_options(media_profile) ++
        sponsorblock_options(media_profile) ++
        output_options(media_item_with_preloads) ++
        config_file_options(media_item_with_preloads)

    {:ok, built_options}
  end

  @doc """
  Builds the output path for yt-dlp to download media based on the given source's
  media profile. Uses the source's override output path template if it exists.

  Accepts a %MediaItem{} or %Source{} struct. If a %Source{} struct is passed, it
  will use a default %MediaItem{} struct with the given source.

  Returns binary()
  """
  def build_output_path_for(%MediaItem{} = media_item_with_preloads) do
    output_path_template = Sources.output_path_template(media_item_with_preloads.source)

    build_output_path(output_path_template, media_item_with_preloads)
  end

  def build_output_path_for(%Source{} = source_with_preloads) do
    build_output_path_for(%MediaItem{source: source_with_preloads})
  end

  defp default_options(override_opts) do
    overwrite_behaviour = Keyword.get(override_opts, :overwrite_behaviour, :force_overwrites)

    [
      :no_progress,
      overwrite_behaviour,
      # This makes the date metadata conform to what jellyfin expects
      parse_metadata: "%(upload_date>%Y-%m-%d)s:(?P<meta_date>.+)"
    ]
  end

  defp subtitle_options(media_profile) do
    mapped_struct = Map.from_struct(media_profile)

    Enum.reduce(mapped_struct, [], fn attr, acc ->
      case {attr, media_profile} do
        {{:download_subs, true}, _} ->
          # Force SRT for now - MAY provide as an option in the future
          acc ++ [:write_subs, convert_subs: "srt"]

        {{:download_auto_subs, true}, %{download_subs: true}} ->
          acc ++ [:write_auto_subs]

        {{:embed_subs, true}, %{preferred_resolution: pr}} when pr != :audio ->
          acc ++ [:embed_subs]

        {{:sub_langs, sub_langs}, %{download_subs: true}} ->
          acc ++ [sub_langs: sub_langs]

        {{:sub_langs, sub_langs}, %{embed_subs: true}} ->
          acc ++ [sub_langs: sub_langs]

        _ ->
          acc
      end
    end)
  end

  defp thumbnail_options(media_item_with_preloads) do
    media_profile = media_item_with_preloads.source.media_profile
    mapped_struct = Map.from_struct(media_profile)

    Enum.reduce(mapped_struct, [], fn attr, acc ->
      case attr do
        {:download_thumbnail, true} ->
          thumbnail_save_location = determine_thumbnail_location(media_item_with_preloads)

          acc ++ [:write_thumbnail, convert_thumbnail: "jpg", output: "thumbnail:#{thumbnail_save_location}"]

        {:embed_thumbnail, true} ->
          acc ++ [:embed_thumbnail, convert_thumbnail: "jpg"]

        _ ->
          acc
      end
    end)
  end

  defp metadata_options(media_profile) do
    mapped_struct = Map.from_struct(media_profile)

    Enum.reduce(mapped_struct, [], fn attr, acc ->
      case attr do
        {:download_metadata, true} -> acc ++ [:write_info_json, :clean_info_json]
        {:embed_metadata, true} -> acc ++ [:embed_metadata]
        _ -> acc
      end
    end)
  end

  defp quality_options(media_profile) do
    video_codec_option = fn res ->
      [format_sort: "res:#{res},+codec:avc:m4a", remux_video: "mp4"]
    end

    audio_format_precedence = [
      "bestaudio[ext=m4a]",
      "bestaudio[ext=mp3]",
      "bestaudio",
      "best[ext=m4a]",
      "best[ext=mp3]",
      "best"
    ]

    case media_profile.preferred_resolution do
      # Also be aware that :audio disabled all embedding options for subtitles
      :audio -> [:extract_audio, format: Enum.join(audio_format_precedence, "/")]
      :"360p" -> video_codec_option.("360")
      :"480p" -> video_codec_option.("480")
      :"720p" -> video_codec_option.("720")
      :"1080p" -> video_codec_option.("1080")
      :"2160p" -> video_codec_option.("2160")
    end
  end

  defp sponsorblock_options(media_profile) do
    categories = media_profile.sponsorblock_categories
    behaviour = media_profile.sponsorblock_behaviour

    case {behaviour, categories} do
      {_, []} -> []
      {:remove, _} -> [sponsorblock_remove: Enum.join(categories, ",")]
      {:disabled, _} -> []
    end
  end

  # This is put here instead of the CommandRunner module because it should only
  # be applied to downloading - if it were in CommandRunner it would apply to
  # all yt-dlp commands (like indexing)
  defp config_file_options(media_item) do
    base_dir = Path.join(Application.get_env(:pinchflat, :extras_directory), "yt-dlp-configs")
    # Ordered by priority - the first file has the highest priority
    filenames = [
      "media-item-#{media_item.id}-config.txt",
      "source-#{media_item.source_id}-config.txt",
      "media-profile-#{media_item.source.media_profile_id}-config.txt",
      "base-config.txt"
    ]

    config_filepaths =
      Enum.reduce(filenames, [], fn filename, acc ->
        filepath = Path.join(base_dir, filename)

        if FSUtils.exists_and_nonempty?(filepath) do
          [filepath | acc]
        else
          acc
        end
      end)

    Enum.map(config_filepaths, fn filepath -> {:config_locations, filepath} end)
  end

  defp output_options(media_item_with_preloads) do
    [
      output: build_output_path_for(media_item_with_preloads)
    ]
  end

  defp build_output_path(string, media_item_with_preloads) do
    additional_options_map = output_options_map(media_item_with_preloads)
    {:ok, output_path} = OutputPathBuilder.build(string, additional_options_map)

    Path.join(base_directory(), output_path)
  end

  defp output_options_map(media_item_with_preloads) do
    source = media_item_with_preloads.source

    %{
      "source_custom_name" => source.custom_name,
      "source_collection_id" => source.collection_id,
      "source_collection_name" => source.collection_name,
      "source_collection_type" => to_string(source.collection_type),
      "media_upload_date_index" =>
        media_item_with_preloads.upload_date_index
        |> to_string()
        |> String.pad_leading(2, "0")
    }
  end

  # I don't love the string manipulation here, but what can ya' do.
  # It's dependent on the output_path_template being a string ending `.{{ ext }}`
  # (or equivalent), but that's validated by the MediaProfile schema.
  defp determine_thumbnail_location(media_item_with_preloads) do
    output_path_template = Sources.output_path_template(media_item_with_preloads.source)

    output_path_template
    |> String.split(~r{\.}, include_captures: true)
    |> List.insert_at(-3, "-thumb")
    |> Enum.join()
    |> build_output_path(media_item_with_preloads)
  end

  defp base_directory do
    Application.get_env(:pinchflat, :media_directory)
  end
end
