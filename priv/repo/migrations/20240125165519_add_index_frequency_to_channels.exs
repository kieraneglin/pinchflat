defmodule Pinchflat.Repo.Migrations.AddIndexFrequencyToSources do
  use Ecto.Migration

  def change do
    alter table(:sources) do
      add :index_frequency_minutes, :integer, default: 60 * 24, null: false
    end
  end
end
