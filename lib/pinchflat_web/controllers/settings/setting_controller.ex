defmodule PinchflatWeb.Settings.SettingController do
  use PinchflatWeb, :controller

  # import Ecto.Query, warn: false

  # alias Pinchflat.Repo
  alias Pinchflat.Settings

  # TODO: test
  def show(conn, _params) do
    setting = Settings.record()
    changeset = Settings.change_setting(setting)

    render(conn, "show.html", changeset: changeset)
  end

  def update(conn, %{"setting" => setting_params}) do
    setting = Settings.record()

    case Settings.update_setting(setting, setting_params) do
      {:ok, setting} ->
        conn
        |> put_flash(:info, "Settings updated successfully.")
        |> redirect(to: ~p"/settings")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "show.html", changeset: changeset)
    end
  end
end
