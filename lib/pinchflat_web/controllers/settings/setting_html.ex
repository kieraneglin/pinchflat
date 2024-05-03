defmodule PinchflatWeb.Settings.SettingHTML do
  use PinchflatWeb, :html

  embed_templates "setting_html/*"

  @doc """
  Renders a setting form.
  """
  attr :conn, Plug.Conn, required: true
  attr :changeset, Ecto.Changeset, required: true
  attr :action, :string, required: true

  def setting_form(assigns)

  def apprise_server_help do
    url = "https://github.com/caronc/apprise/wiki/URLBasics"
    classes = "underline decoration-bodydark decoration-1 hover:decoration-white"

    ~s(Server endpoint for Apprise notifications when new media is found. See <a href="#{url}" class="#{classes}" target="_blank">Apprise docs</a> for more information)
  end
end
