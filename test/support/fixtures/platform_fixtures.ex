defmodule Pinchflat.PlatformFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Pinchflat.Platform` context.
  """

  @doc """
  Generate an app_notification.
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

  @doc """
  Generate an app_notification JSON fixture.
  """
  def app_notification_json_fixture(attrs \\ %{}) do
    attrs
    |> Enum.into(%{
      title: "a cool title",
      body: "a cool notification",
      notification_date: ~D[2020-01-01],
      read_at: nil,
      severity: :alert,
      uuid: Ecto.UUID.generate()
    })
    |> Phoenix.json_library().encode!()
  end
end
