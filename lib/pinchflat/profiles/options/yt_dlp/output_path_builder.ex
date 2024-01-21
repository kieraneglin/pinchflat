defmodule Pinchflat.Profiles.Options.YtDlp.OutputPathBuilder do
  @moduledoc """
  Builds yt-dlp-friendly output paths for downloaded media

  TODO: probably make this a behaviour so I can add other backends later
  """

  alias Pinchflat.RenderedString.Parser, as: TemplateParser

  @doc """
  Builds the actual final filepath from a given template.

  Translates liquid-style templates into yt-dlp-style templates,
  leaving yt-dlp syntax intact.

  TODO: test
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
      "id" => "%(id)s",
      "ext" => "%(ext)s",
      "title" => "%(title)s",
      "fulltitle" => "%(fulltitle)s",
      "uploader" => "%(uploader)s",
      "creator" => "%(creator)s",
      "upload_date" => "%(upload_date)s",
      "release_date" => "%(release_date)s",
      "duration" => "%(duration)s",
      # For videos classified as an episode of a series:
      "series" => "%(series)s",
      "season" => "%(season)s",
      "season_number" => "%(season_number)s",
      "episode" => "%(episode)s",
      "episode_number" => "%(episode_number)s",
      "episode_id" => "%(episode_id)s",
      # For videos classified as music:
      "track" => "%(track)s",
      "track_number" => "%(track_number)s",
      "artist" => "%(artist)s",
      "album" => "%(album)s",
      "album_type" => "%(album_type)s",
      "genre" => "%(genre)s"
    }
  end

  defp custom_yt_dlp_option_map do
    %{
      # Filepath-safe versions of some standard options
      "safe_id" => "%(id)S",
      "safe_title" => "%(title)S",
      "safe_fulltitle" => "%(fulltitle)S",
      "safe_uploader" => "%(uploader)S",
      "safe_creator" => "%(creator)S",
      # Individual parts of the upload date
      "upload_year" => "%(upload_date>%Y)s",
      "upload_month" => "%(upload_date>%m)s",
      "upload_day" => "%(upload_date>%d)s"
    }
  end
end
