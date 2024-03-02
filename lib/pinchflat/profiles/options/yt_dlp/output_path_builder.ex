defmodule Pinchflat.Profiles.Options.YtDlp.OutputPathBuilder do
  @moduledoc """
  Builds yt-dlp-friendly output paths for downloaded media

  IDEA: consider making this a behaviour so I can add other backends later
  """

  alias Pinchflat.RenderedString.Parser, as: TemplateParser

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

  defp custom_yt_dlp_option_map do
    %{
      # Individual parts of the upload date
      "upload_year" => "%(upload_date>%Y)S",
      "upload_month" => "%(upload_date>%m)S",
      "upload_day" => "%(upload_date>%d)S"
    }
  end
end
