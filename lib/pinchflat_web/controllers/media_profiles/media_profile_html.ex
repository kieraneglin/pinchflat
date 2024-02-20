defmodule PinchflatWeb.MediaProfiles.MediaProfileHTML do
  use PinchflatWeb, :html

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
      {"2160p", "4k"},
      {"1080p", "1080p"},
      {"720p", "720p"},
      {"480p", "480p"},
      {"360p", "360p"}
    ]
  end

  def custom_output_template_options do
    ~w(upload_day upload_month upload_year)a
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
end
