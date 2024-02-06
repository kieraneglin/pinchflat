defmodule Pinchflat.Profiles.Options.YtDlp.OutputPathBuilder do
  @moduledoc """
  Builds yt-dlp-friendly output paths for downloaded media

  IDEA: consider making this a behaviour so I can add other backends later
  """

  alias Pinchflat.RenderedString.Parser, as: TemplateParser

  @doc """
  Builds the actual final filepath from a given template.

  Translates liquid-style templates into yt-dlp-style templates,
  leaving yt-dlp syntax intact.

  IDEA: apart from any custom options I've defined, I can support any yt-dlp
  option by assuming `{{ identifier }}` should transform to `%(identifier)S`.
  It's not doing anything huge, but it's nicer to type and more approachable IMO.
  IDEA: set a default for `MediaProfile`'s `output_path_template` field
  """
  def build(template_string) do
    TemplateParser.parse(template_string, full_yt_dlp_options_map())
  end

  defp full_yt_dlp_options_map do
    Map.merge(
      standard_yt_dlp_option_map(),
      custom_yt_dlp_option_map()
    )
  end

  defp standard_yt_dlp_option_map do
    %{
      # Uppercase "S" means "safe" - ie: filepath-safe
      "id" => "%(id)S",
      "ext" => "%(ext)S",
      "title" => "%(title)S",
      "fulltitle" => "%(fulltitle)S",
      "uploader" => "%(uploader)S",
      "creator" => "%(creator)S",
      "upload_date" => "%(upload_date)S",
      "release_date" => "%(release_date)S",
      "duration" => "%(duration)S",
      # For videos classified as an episode of a series:
      "series" => "%(series)S",
      "season" => "%(season)S",
      "season_number" => "%(season_number)S",
      "episode" => "%(episode)S",
      "episode_number" => "%(episode_number)S",
      "episode_id" => "%(episode_id)S",
      # For videos classified as music:
      "track" => "%(track)S",
      "track_number" => "%(track_number)S",
      "artist" => "%(artist)S",
      "album" => "%(album)S",
      "album_type" => "%(album_type)S",
      "genre" => "%(genre)S"
    }
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
