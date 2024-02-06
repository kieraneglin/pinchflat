defmodule Pinchflat.Profiles.Options.YtDlp.IndexOptionBuilder do
  @moduledoc """
  Builds the options for yt-dlp to index a media source based on the given media profile.
  """

  alias Pinchflat.Profiles.MediaProfile

  @doc """
  Builds the options for yt-dlp to index a media source based on the given media profile.
  """
  def build(%MediaProfile{} = media_profile) do
    built_options = release_type_options(media_profile)

    {:ok, built_options}
  end

  defp release_type_options(media_profile) do
    mapped_struct = Map.from_struct(media_profile)

    # Appending multiple match filters treats them as an OR condition,
    # so we have to be careful around combining `only` and `exclude` options.
    # eg: only shorts + exclude livestreams = "any video that is a short OR is not a livestream"
    # which will return all shorts AND normal videos.
    Enum.reduce(mapped_struct, [], fn attr, acc ->
      case {attr, media_profile} do
        {{:shorts_behaviour, :only}, _} ->
          acc ++ [match_filter: "original_url*=/shorts/"]

        {{:livestream_behaviour, :only}, _} ->
          acc ++ [match_filter: "was_live"]

        # Since match_filter is an OR (see above), `exclude`s must be ignored entirely if the
        # other type is set to `only`. There is also special behaviour if they're both excludes,
        # hence why these check against `:include` alone.
        {{:shorts_behaviour, :exclude}, %{livestream_behaviour: :include}} ->
          acc ++ [match_filter: "original_url!*=/shorts/"]

        {{:livestream_behaviour, :exclude}, %{shorts_behaviour: :include}} ->
          acc ++ [match_filter: "!was_live"]

        # Again, since it's an OR, there's a special syntax if they're both excluded
        # to make it an AND. Note that I'm not checking for the other permutation of
        # both excluding since this MUST get hit so adding the other version would double up.
        {{:livestream_behaviour, :exclude}, %{shorts_behaviour: :exclude}} ->
          acc ++ [match_filter: "!was_live & original_url!*=/shorts/"]

        _ ->
          acc
      end
    end)
  end
end
