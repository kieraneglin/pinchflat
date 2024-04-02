defmodule Pinchflat.Repo.Migrations.AddPreventDownloadToMediaItems do
  use Ecto.Migration

  def change do
    alter table(:media_items) do
      add :prevent_download, :boolean, default: false, null: false
    end
  end
end
