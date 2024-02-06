defmodule Pinchflat.Repo.Migrations.AddDownloadMediaToSources do
  use Ecto.Migration

  def change do
    alter table(:sources) do
      add :download_media, :boolean, default: true, null: false
    end
  end
end
