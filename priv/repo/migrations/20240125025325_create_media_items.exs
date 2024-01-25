defmodule Pinchflat.Repo.Migrations.CreateMediaItems do
  use Ecto.Migration

  def change do
    create table(:media_items) do
      add :media_id, :string, null: false
      add :title, :string
      add :video_filepath, :string
      add :channel_id, references(:channels, on_delete: :restrict), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:media_items, [:channel_id])
    create unique_index(:media_items, [:media_id, :channel_id])
  end
end
