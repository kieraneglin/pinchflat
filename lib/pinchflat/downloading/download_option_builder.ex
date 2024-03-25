defmodule Pinchflat.Downloading.DownloadOptionBuilder do
  @moduledoc """
  Builds the options for yt-dlp to download media based on the given media profile.
  """

  alias Pinchflat.Sources.Source
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
        cookie_options() ++
        subtitle_options(media_profile) ++
        thumbnail_options(media_item_with_preloads) ++
        metadata_options(media_profile) ++
        quality_options(media_profile) ++
        output_options(media_item_with_preloads)

    {:ok, built_options}
  end

  @doc """
  Builds the output path for yt-dlp to download media based on the given source's
  media profile.

  Returns binary()
  """
  def build_output_path_for(%Source{} = source_with_preloads) do
    output_path_template = source_with_preloads.media_profile.output_path_template

    build_output_path(output_path_template, source_with_preloads)
  end

  defp default_options do
    [:no_progress, :windows_filenames]
  end

  defp cookie_options do
    base_dir = Application.get_env(:pinchflat, :extras_directory)
    cookie_file = Path.join(base_dir, "cookies.txt")

    case File.read(cookie_file) do
      {:ok, cookie_data} ->
        if String.trim(cookie_data) != "", do: [cookies: cookie_file], else: []

      {:error, _} ->
        []
    end
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
    video_codec_options = "+codec:avc:m4a"

    case media_profile.preferred_resolution do
      # Also be aware that :audio disabled all embedding options for subtitles
      :audio -> [:extract_audio, format: "bestaudio[ext=m4a]"]
      :"360p" -> [format_sort: "res:360,#{video_codec_options}"]
      :"480p" -> [format_sort: "res:480,#{video_codec_options}"]
      :"720p" -> [format_sort: "res:720,#{video_codec_options}"]
      :"1080p" -> [format_sort: "res:1080,#{video_codec_options}"]
      :"2160p" -> [format_sort: "res:2160,#{video_codec_options}"]
    end
  end

  defp output_options(media_item_with_preloads) do
    [
      output: build_output_path_for(media_item_with_preloads.source)
    ]
  end

  defp build_output_path(string, source) do
    additional_options_map = output_options_map(source)
    {:ok, output_path} = OutputPathBuilder.build(string, additional_options_map)

    Path.join(base_directory(), output_path)
  end

  defp output_options_map(source) do
    %{
      "source_custom_name" => source.custom_name,
      "source_collection_type" => source.collection_type
    }
  end

  # I don't love the string manipulation here, but what can ya' do.
  # It's dependent on the output_path_template being a string ending `.{{ ext }}`
  # (or equivalent), but that's validated by the MediaProfile schema.
  defp determine_thumbnail_location(media_item_with_preloads) do
    output_path_template = media_item_with_preloads.source.media_profile.output_path_template

    output_path_template
    |> String.split(~r{\.}, include_captures: true)
    |> List.insert_at(-3, "-thumb")
    |> Enum.join()
    |> build_output_path(media_item_with_preloads.source)
  end

  defp base_directory do
    Application.get_env(:pinchflat, :media_directory)
  end
end
