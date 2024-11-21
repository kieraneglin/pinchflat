defmodule Pinchflat.Repo.Migrations.AddEnabledToSources do
  use Ecto.Migration

  def change do
    alter table(:sources) do
      add :enabled, :boolean, default: true, null: false
    end
  end
end
