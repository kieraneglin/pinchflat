defmodule Pinchflat.Platform do
  @moduledoc """
  The Platform context.
  """

  import Ecto.Query, warn: false
  alias Pinchflat.Repo

  alias Pinchflat.Platform.AppNotification

  @doc """
  Returns the list of app_notifications.

  Returns [%AppNotification{}, ...]
  """
  def list_app_notifications do
    Repo.all(AppNotification)
  end

  @doc """
  Creates a app_notification.

  Returns {:ok, %AppNotification{}} | {:error, %Ecto.Changeset{}}
  """
  def create_app_notification(attrs \\ %{}) do
    %AppNotification{}
    |> AppNotification.changeset(attrs)
    |> IO.inspect()
    |> Repo.insert()
  end

  # def mark_all_as_read do
  #   Repo.update_all(AppNotification, set: [read_at: DateTime.utc_now()])
  # end

  @doc """
  Returns `%Ecto.Changeset{}`
  """
  def change_app_notification(%AppNotification{} = app_notification, attrs \\ %{}) do
    AppNotification.changeset(app_notification, attrs)
  end
end
