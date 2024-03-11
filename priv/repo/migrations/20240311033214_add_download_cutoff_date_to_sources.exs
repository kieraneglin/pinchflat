defmodule Pinchflat.Repo.Migrations.AddDownloadCutoffDateToSources do
  use Ecto.Migration

  def change do
    alter table(:sources) do
      add :download_cutoff_date, :date
    end
  end
end
