defmodule PinchflatWeb.Settings.SettingHTML do
  use PinchflatWeb, :html

  alias Pinchflat.Downloading.CodecParser

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

  def diagnostic_info_string do
    """
    - App Version: #{Application.spec(:pinchflat)[:vsn]}
    - yt-dlp Version: #{Settings.get!(:yt_dlp_version)}
    - Apprise Version: #{Settings.get!(:apprise_version)}
    - System Architecture: #{to_string(:erlang.system_info(:system_architecture))}
    - Timezone: #{Application.get_env(:pinchflat, :timezone)}
    """
  end
end
