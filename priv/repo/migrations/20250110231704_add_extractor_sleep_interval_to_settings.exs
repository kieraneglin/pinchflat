defmodule Pinchflat.Repo.Migrations.AddExtractorSleepIntervalToSettings do
  use Ecto.Migration

  def change do
    alter table(:settings) do
      add :extractor_sleep_interval_seconds, :number, null: false, default: 0
    end
  end
end
