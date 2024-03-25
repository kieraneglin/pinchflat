defmodule PinchflatWeb.MediaProfiles.MediaProfileHTML do
  use PinchflatWeb, :html

  alias Pinchflat.Profiles.MediaProfile

  embed_templates "media_profile_html/*"

  @doc """
  Renders a media_profile form.
  """
  attr :changeset, Ecto.Changeset, required: true
  attr :action, :string, required: true

  def media_profile_form(assigns)

  def friendly_format_type_options do
    [
      {"Include (default)", :include},
      {"Exclude", :exclude},
      {"Only", :only}
    ]
  end

  def friendly_resolution_options do
    [
      {"4k", "2160p"},
      {"1080p", "1080p"},
      {"720p", "720p"},
      {"480p", "480p"},
      {"360p", "360p"},
      {"Audio Only", "audio"}
    ]
  end

  def custom_output_template_options do
    %{
      upload_day: nil,
      upload_month: nil,
      upload_year: nil,
      upload_yyyy_mm_dd: "the upload date in the format YYYY-MM-DD",
      source_custom_name: "the name of the sources that use this profile",
      source_collection_type: "the collection type of the sources using this profile. Either 'channel' or 'playlist'",
      artist_name: "the name of the artist with fallbacks to other uploader fields"
    }
  end

  def common_output_template_options do
    ~w(
      id
      ext
      title
      fulltitle
      uploader
      channel
      upload_date
      duration_string
    )a
  end

  def preset_options do
    [
      {"Default", "default"},
      {"Media Center (Plex, Jellyfin, Kodi, etc.)", "media_center"},
      {"Music", "audio"},
      {"Archiving", "archiving"}
    ]
  end

  defp default_output_template do
    %MediaProfile{}.output_path_template
  end

  defp media_center_output_template do
    "/shows/{{ source_custom_name }}/Season {{ season_from_date }}/{{ season_episode_from_date }} - {{ title }}.{{ ext }}"
  end

  defp audio_output_template do
    "/music/{{ artist_name }}/{{ title }}.{{ ext }}"
  end
end
