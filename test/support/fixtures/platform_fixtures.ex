defmodule Pinchflat.PlatformFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Pinchflat.Platform` context.
  """

  @doc """
  Generate a app_notification.
  """
  def app_notification_fixture(attrs \\ %{}) do
    {:ok, app_notification} =
      attrs
      |> Enum.into(%{
        title: "a cool title",
        body: "a cool notification",
        notification_date: ~D[2020-01-01],
        read_at: nil,
        severity: :alert,
        uuid: Ecto.UUID.generate()
      })
      |> Pinchflat.Platform.create_app_notification()

    app_notification
  end
end
