defmodule Pinchflat.Repo.Migrations.AddDownloadNfoToMediaProfile do
  use Ecto.Migration

  def change do
    alter table(:media_profiles) do
      add :download_nfo, :boolean, default: false, null: false
    end
  end
end
