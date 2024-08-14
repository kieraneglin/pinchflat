defmodule Pinchflat.Repo.Migrations.AddDurationLimitsToSources do
  use Ecto.Migration

  def change do
    alter table(:sources) do
      add :min_duration_seconds, :integer
      add :max_duration_seconds, :integer
    end
  end
end
