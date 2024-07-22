defmodule Pinchflat.Downloading.OutputPathBuilder do
  @moduledoc """
  Builds yt-dlp-friendly output paths for downloaded media
  """

  alias Pinchflat.Downloading.OutputPath.Parser, as: TemplateParser

  @doc """
  Builds the actual final filepath from a given template. Optionally, you can pass in
  a map of additional options to be used in the template.

  Custom options are recursively expanded _once_ so you can nest custom options
  one-deep if needed.

  Translates liquid-style templates into yt-dlp-style templates,
  leaving yt-dlp syntax intact.
  """
  def build(template_string, additional_template_options \\ %{}) do
    combined_options = Map.merge(custom_yt_dlp_option_map(), additional_template_options)

    expanded_options =
      Enum.map(combined_options, fn {key, value} ->
        {:ok, parse_result} = TemplateParser.parse(value, combined_options, &identifier_fn/2)

        {key, parse_result}
      end)

    TemplateParser.parse(template_string, Map.new(expanded_options), &identifier_fn/2)
  end

  # The `nil` case simply wraps the identifier in yt-dlp-style syntax. This assumes that
  # the identifier is a valid yt-dlp option. The upside is that this gives the user
  # access to ALL single-word yt-dlp options in the (imo) more friendly/forgiving liquid-style syntax.
  #
  # For all "custom" variables, we use the `Map.get/3` function to look up the value in the provided.
  # See `custom_yt_dlp_option_map` for a list of those.
  defp identifier_fn(identifier, variables) do
    case Map.get(variables, identifier) do
      nil -> "%(#{identifier})S"
      value -> value
    end
  end

  # This isn't the only source for custom options, since they can be passed in my the caller.
  # `download_option_builder` is the most likely place for other custom options to be added,
  # but if in doubt just search the codebase for `OutputPathBuilder.build`.
  defp custom_yt_dlp_option_map do
    %{
      # Individual parts of the upload date
      "upload_year" => "%(upload_date>%Y)S",
      "upload_month" => "%(upload_date>%m)S",
      "upload_day" => "%(upload_date>%d)S",
      "upload_yyyy_mm_dd" => "%(upload_date>%Y-%m-%d)S",
      "season_from_date" => "%(upload_date>%Y)S",
      "season_episode_from_date" => "s%(upload_date>%Y)Se%(upload_date>%m%d)S",
      "season_episode_index_from_date" => "s%(upload_date>%Y)Se%(upload_date>%m%d)S{{ media_upload_date_index }}",
      "artist_name" => "%(artist,creator,uploader,uploader_id)S",
      "static_season__episode_by_index" => "Season 1/s01e{{ media_playlist_index }}",
      "static_season__episode_by_date" => "Season 1/s01e%(upload_date>%y%m%d)S",
      "season_by_year__episode_by_date" => "Season %(upload_date>%Y)S/s%(upload_date>%Y)Se%(upload_date>%m%d)S",
      "season_by_year__episode_by_date_and_index" =>
        "Season %(upload_date>%Y)S/s%(upload_date>%Y)Se%(upload_date>%m%d)S{{ media_upload_date_index }}"
    }
  end
end
