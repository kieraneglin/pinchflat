defmodule PinchflatWeb.MediaProfiles.MediaProfileHTML do
  use PinchflatWeb, :html

  alias Pinchflat.Profiles.MediaProfile

  embed_templates "media_profile_html/*"

  @doc """
  Renders a media_profile form.
  """
  attr :changeset, Ecto.Changeset, required: true
  attr :action, :string, required: true
  attr :method, :string, required: true

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
      {"8k", "4320p"},
      {"4k", "2160p"},
      {"1440p", "1440p"},
      {"1080p", "1080p"},
      {"720p", "720p"},
      {"480p", "480p"},
      {"360p", "360p"},
      {"Audio Only", "audio"}
    ]
  end

  def friendly_sponsorblock_options do
    [
      {"Disabled (default)", "disabled"},
      {"Remove Segments", "remove"}
    ]
  end

  def frieldly_sponsorblock_categories do
    [
      {"Sponsor", "sponsor"},
      {"Intro/Intermission", "intro"},
      {"Outro/Credits", "outro"},
      {"Self Promotion", "selfpromo"},
      {"Preview/Recap", "preview"},
      {"Filler Tangent", "filler"},
      {"Interaction Reminder", "interaction"},
      {"Non-music Section", "music_offtopic"}
    ]
  end

  def media_center_custom_output_template_options do
    %{
      season_by_year__episode_by_date: "<code>Season YYYY/sYYYYeMMDD</code>",
      season_by_year__episode_by_date_and_index:
        "same as the above but it handles dates better. <strong>This is the recommended option</strong>",
      static_season__episode_by_index:
        "<code>Season 1/s01eXX</code> where <code>XX</code> is the video's position in the playlist. Only recommended for playlists (not channels) that don't change",
      static_season__episode_by_date:
        "<code>Season 1/s01eYYMMDD</code>. Recommended for playlists that might change or where order isn't important"
    }
  end

  def other_custom_output_template_options do
    %{
      upload_day: nil,
      upload_month: nil,
      upload_year: nil,
      upload_yyyy_mm_dd: "the upload date in the format <code>YYYY-MM-DD</code>",
      source_custom_name: "the name of the sources that use this profile",
      source_collection_id: "the YouTube ID of the sources that use this profile",
      source_collection_name:
        "the YouTube name of the sources that use this profile (often the same as source_custom_name)",
      source_collection_type: "the collection type of the sources using this profile. Either 'channel' or 'playlist'",
      artist_name: "the name of the artist with fallbacks to other uploader fields",
      season_from_date: "alias for upload_year",
      season_episode_from_date: "the upload date formatted as <code>sYYYYeMMDD</code>",
      season_episode_index_from_date:
        "the upload date formatted as <code>sYYYYeMMDDII</code> where <code>II</code> is an index to prevent date collisions",
      media_playlist_index:
        "the place of the media item in the playlist. Do not use with channels. May not work if the playlist is updated"
    }
  end

  def common_output_template_options do
    ~w(
      id
      ext
      title
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
    "/shows/{{ source_custom_name }}/{{ season_by_year__episode_by_date_and_index }} - {{ title }}.{{ ext }}"
  end

  defp audio_output_template do
    "/music/{{ artist_name }}/{{ title }}.{{ ext }}"
  end
end
