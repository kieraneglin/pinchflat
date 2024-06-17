defmodule Pinchflat.Repo.Migrations.CreateAppNotifications do
  use Ecto.Migration

  def change do
    create table(:app_notifications) do
      add :uuid, :string, null: false
      add :title, :string, null: false
      add :body, :string
      add :severity, :string, null: false
      add :notification_date, :date, null: false
      add :read_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create(unique_index(:app_notifications, [:uuid]))
  end
end
