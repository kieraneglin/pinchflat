defmodule Pinchflat.Platform.AppNotification do
  @moduledoc """
  The AppNotification schema.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @allowed_fields ~w(
    uuid
    title
    body
    severity
    notification_date
    read_at
  )a

  @required_fields ~w(uuid title severity notification_date)a

  schema "app_notifications" do
    # NOTE: this is _not_ used as a primary key, but as a unique identifier for all installations
    field :uuid, Ecto.UUID
    field :title, :string
    field :body, :string
    field :severity, Ecto.Enum, values: Logger.levels()
    field :notification_date, :date
    field :read_at, :naive_datetime

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(app_notification, attrs) do
    app_notification
    |> cast(attrs, @allowed_fields)
    |> validate_required(@required_fields)
  end
end
