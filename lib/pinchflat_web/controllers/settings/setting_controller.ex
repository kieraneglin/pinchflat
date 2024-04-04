defmodule PinchflatWeb.Settings.SettingController do
  use PinchflatWeb, :controller

  import Ecto.Query, warn: false

  alias Pinchflat.Repo

  def edit(conn, _params) do
    render(conn, "edit.html")
  end
end
