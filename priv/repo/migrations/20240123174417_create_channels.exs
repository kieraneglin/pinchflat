defmodule Pinchflat.Repo.Migrations.CreateSources do
  use Ecto.Migration

  def change do
    create table(:sources) do
      add :name, :string, null: false
      add :collection_id, :string, null: false
      add :collection_type, :string, null: false
      add :original_url, :string, null: false
      add :media_profile_id, references(:media_profiles, on_delete: :restrict), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:sources, [:media_profile_id])
    create unique_index(:sources, [:collection_id, :media_profile_id])
  end
end
