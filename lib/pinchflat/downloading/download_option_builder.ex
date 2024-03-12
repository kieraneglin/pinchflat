defmodule Pinchflat.Downloading.DownloadOptionBuilder do
  @moduledoc """
  Builds the options for yt-dlp to download media based on the given media profile.
  """

  alias Pinchflat.Media.MediaItem
  alias Pinchflat.Downloading.OutputPathBuilder

  @doc """
  Builds the options for yt-dlp to download media based on the given media's profile.

  IDEA: consider adding the ability to pass in a second argument to override
        these options
  """
  def build(%MediaItem{} = media_item_with_preloads) do
    media_profile = media_item_with_preloads.source.media_profile

    built_options =
      default_options() ++
        subtitle_options(media_profile) ++
        thumbnail_options(media_profile) ++
        metadata_options(media_profile) ++
        quality_options(media_profile) ++
        output_options(media_item_with_preloads)

    {:ok, built_options}
  end

  defp default_options do
    [:no_progress, :windows_filenames]
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

  defp thumbnail_options(media_profile) do
    mapped_struct = Map.from_struct(media_profile)

    Enum.reduce(mapped_struct, [], fn attr, acc ->
      case attr do
        {:download_thumbnail, true} ->
          acc ++ [:write_thumbnail, convert_thumbnail: "jpg"]

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
    video_codec_options = "+codec:avc:m4a"

    case media_profile.preferred_resolution do
      # Also be aware that :audio disabled all embedding options for subtitles
      :audio -> [:extract_audio, format: "bestaudio[ext=m4a]"]
      :"360p" -> [format_sort: "res:360,#{video_codec_options}"]
      :"480p" -> [format_sort: "res:480,#{video_codec_options}"]
      :"720p" -> [format_sort: "res:720,#{video_codec_options}"]
      :"1080p" -> [format_sort: "res:1080,#{video_codec_options}"]
      :"1440p" -> [format_sort: "res:1440,#{video_codec_options}"]
      :"2160p" -> [format_sort: "res:2160,#{video_codec_options}"]
    end
  end

  defp output_options(media_item_with_preloads) do
    media_profile = media_item_with_preloads.source.media_profile
    additional_options_map = output_options_map(media_item_with_preloads)
    {:ok, output_path} = OutputPathBuilder.build(media_profile.output_path_template, additional_options_map)

    [
      output: Path.join(base_directory(), output_path)
    ]
  end

  defp output_options_map(media_item_with_preloads) do
    source = media_item_with_preloads.source

    %{
      "source_custom_name" => source.custom_name,
      "source_collection_type" => source.collection_type
    }
  end

  defp base_directory do
    Application.get_env(:pinchflat, :media_directory)
  end
end
