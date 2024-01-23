defmodule PinchflatWeb.MediaProfiles.MediaProfileHTML do
  use PinchflatWeb, :html

  embed_templates "media_profile_html/*"

  @doc """
  Renders a media_profile form.
  """
  attr :changeset, Ecto.Changeset, required: true
  attr :action, :string, required: true

  def media_profile_form(assigns)
end
