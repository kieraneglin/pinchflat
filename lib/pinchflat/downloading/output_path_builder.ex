defmodule Pinchflat.Downloading.OutputPathBuilder do
  @moduledoc """
  Builds yt-dlp-friendly output paths for downloaded media
  """

  alias Pinchflat.Downloading.OutputPath.Parser, as: TemplateParser

  @doc """
  Builds the actual final filepath from a given template. Optionally, you can pass in
  a map of additional options to be used in the template.

  Translates liquid-style templates into yt-dlp-style templates,
  leaving yt-dlp syntax intact.
  """
  def build(template_string, additional_template_options \\ %{}) do
    combined_options = Map.merge(custom_yt_dlp_option_map(), additional_template_options)

    TemplateParser.parse(template_string, combined_options, &identifier_fn/2)
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
      "season_episode_from_date" => "s%(upload_date>%Y)Se%(upload_date>%m%d)S"
    }
  end
end
