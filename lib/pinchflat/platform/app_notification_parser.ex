defmodule Pinchflat.Platform.AppNotificationParser do
  alias Pinchflat.Platform

  def parse_and_store_notifications(notification_json) do
    {:ok, notifications} =
      notification_json
      |> parse_notification_json!()
      |> store_notifications()

    {:ok, notifications}
  end

  defp parse_notification_json!(json) do
    Phoenix.json_library().decode!(json)
  end

  defp store_notifications(notification_json) do
    Enum.map(notification_json, fn notification ->
      {:ok, notification} = Platform.create_app_notification(notification)

      notification
    end)
  end

  # defp prior_notifications_exist? do
  #   # TODO
  # end
end
