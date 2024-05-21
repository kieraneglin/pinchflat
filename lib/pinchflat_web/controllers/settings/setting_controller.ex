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
    IO.inspect(setting_params)

    case Settings.update_setting(setting, setting_params) do
      {:ok, _} ->
        conn
        |> put_flash(:info, "Settings updated successfully.")
        |> redirect(to: ~p"/settings")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "show.html", changeset: changeset)
    end
  end

  def app_info(conn, _params) do
    render(conn, "app_info.html")
  end

  def download_logs(conn, _params) do
    log_path = Application.get_env(:pinchflat, :log_path)

    if log_path && File.exists?(log_path) do
      send_download(conn, {:file, log_path}, filename: "pinchflat-logs-#{Date.utc_today()}.txt")
    else
      conn
      |> put_flash(:error, "Log file couldn't be found")
      |> redirect(to: ~p"/app_info")
    end
  end
end
