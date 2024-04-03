defmodule Pinchflat.Repo.Migrations.AddRetentionPeriodToSources do
  use Ecto.Migration

  def change do
    alter table(:sources) do
      add :retention_period_days, :integer
    end
  end
end
