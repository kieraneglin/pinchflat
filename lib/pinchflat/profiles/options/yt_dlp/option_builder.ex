defmodule Pinchflat.Profiles.Options.YtDlp.OptionBuilder do
  @moduledoc """
  Builds the options for yt-dlp based on the given media profile.

  IDEA: consider making this a behaviour so I can add other backends later
  """

  alias Pinchflat.Profiles.MediaProfile
  alias Pinchflat.Profiles.Options.YtDlp.OutputPathBuilder

  @doc """
  Builds the options for yt-dlp based on the given media profile.

  IDEA: consider adding the ability to pass in a second argument to override
        these options
  """
  def build(%MediaProfile{} = media_profile) do
    # NOTE: I'll be hardcoding most things for now (esp. options to help me test) -
    # add more configuration later as I build out the models. Walk before you can run!

    # NOTE: Looks like you can put different media types in different directories.
    # see: https://github.com/yt-dlp/yt-dlp#output-template

    built_options =
      default_options() ++
        subtitle_options(media_profile) ++
        thumbnail_options(media_profile) ++
        output_options(media_profile)

    {:ok, built_options}
  end

  # This will be updated a lot as I add new options to profiles
  defp default_options do
    [
      :embed_metadata,
      :no_progress
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

        {{:embed_subs, true}, _} ->
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
        {:download_thumbnail, true} -> acc ++ [:write_thumbnail]
        {:embed_thumbnail, true} -> acc ++ [:embed_thumbnail]
        _ -> acc
      end
    end)
  end

  defp output_options(media_profile) do
    {:ok, output_path} = OutputPathBuilder.build(media_profile.output_path_template)

    [
      output: Path.join(base_directory(), output_path)
    ]
  end

  defp base_directory do
    Application.get_env(:pinchflat, :media_directory)
  end
end
