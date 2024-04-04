defmodule PinchflatWeb.Settings.SettingHTML do
  use PinchflatWeb, :html

  embed_templates "setting_html/*"

  @doc """
  Renders a setting form.
  """
  attr :changeset, Ecto.Changeset, required: true
  attr :action, :string, required: true

  def setting_form(assigns)
end
