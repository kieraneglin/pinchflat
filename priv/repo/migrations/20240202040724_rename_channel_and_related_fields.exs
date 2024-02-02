defmodule Pinchflat.Repo.Migrations.RenameChannelAndRelatedFields do
  use Ecto.Migration

  def change do
    # Creation
    create table(:sources) do
      add :name, :string, null: false
      add :collection_type, :string, null: false
      add :collection_id, :string, null: false
      add :original_url, :string, null: false
      add :media_profile_id, references(:media_profiles, on_delete: :restrict), null: false
      add :index_frequency_minutes, :integer, default: 60 * 24, null: false

      timestamps(type: :utc_datetime)
    end

    alter table(:media_items) do
      add :source_id, references(:sources, on_delete: :restrict), null: false
    end

    alter table(:tasks) do
      # `restrict` because we need to be sure to delete pending tasks when a source is deleted
      add :source_id, references(:sources, on_delete: :restrict), null: true
    end

    create index(:sources, [:media_profile_id])
    create unique_index(:sources, [:collection_id, :media_profile_id])

    create index(:media_items, [:source_id])
    create unique_index(:media_items, [:media_id, :source_id])

    # Deletion
    drop index(:media_items, [:channel_id])
    drop unique_index(:media_items, [:media_id, :channel_id])

    alter table(:tasks) do
      # `restrict` because we need to be sure to delete pending tasks when a source is deleted
      remove :channel_id, references(:channels, on_delete: :restrict), null: true
    end

    alter table(:media_items) do
      remove :channel_id, references(:channels, on_delete: :restrict), null: true
    end
  end
end
