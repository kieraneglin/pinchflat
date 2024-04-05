defmodule PinchflatWeb.Settings.SettingController do
  use PinchflatWeb, :controller

  alias Pinchflat.Settings

  def show(conn, _params) do
    setting = Settings.record()
    changeset = Settings.change_setting(setting)

    render(conn, "show.html", changeset: changeset)
  end

  def update(conn, %{"setting" => setting_params}) do
    setting = Settings.record()

    case Settings.update_setting(setting, setting_params) do
      {:ok, _} ->
        conn
        |> put_flash(:info, "Settings updated successfully.")
        |> redirect(to: ~p"/settings")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "show.html", changeset: changeset)
    end
  end
end
