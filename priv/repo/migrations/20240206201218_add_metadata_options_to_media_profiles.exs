defmodule Pinchflat.Repo.Migrations.AddMetadataOptionsToMediaProfiles do
  use Ecto.Migration

  def change do
    alter table(:media_profiles) do
      add :download_metadata, :boolean, default: true, null: false
      add :embed_metadata, :boolean, default: true, null: false
    end

    alter table(:media_items) do
      add :metadata_filepath, :string
    end
  end
end
