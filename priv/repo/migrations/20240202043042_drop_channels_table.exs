defmodule Pinchflat.Repo.Migrations.DropChannelsTable do
  use Ecto.Migration

  def up do
    drop table(:channels)
  end

  def down do
    create table(:channels) do
      add :name, :string, null: false
      add :channel_id, :string, null: false
      add :original_url, :string, null: false
      add :media_profile_id, references(:media_profiles, on_delete: :restrict), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:channels, [:media_profile_id])
    create unique_index(:channels, [:channel_id, :media_profile_id])
  end
end
