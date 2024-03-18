defmodule Pinchflat.Repo.Migrations.AddNfoPathToSources do
  use Ecto.Migration

  def change do
    alter table(:sources) do
      add :download_nfo, :boolean, default: false, null: false
      add :nfo_filepath, :string
      add :series_directory, :string
    end
  end
end
