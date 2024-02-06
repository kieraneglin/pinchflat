defmodule Pinchflat.Repo.Migrations.AddThumbnailOptionsToMediaProfiles do
  use Ecto.Migration

  def change do
    alter table(:media_profiles) do
      add :download_thumbnail, :boolean, default: true, null: false
      add :embed_thumbnail, :boolean, default: true, null: false
    end

    alter table(:media_items) do
      add :thumbnail_filepath, :string
    end
  end
end
