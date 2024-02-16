defmodule Pinchflat.Repo.Migrations.CreateMediaItems do
  use Ecto.Migration

  def change do
    create table(:media_items) do
      add :media_id, :string, null: false
      add :title, :string
      add :video_filepath, :string
      add :source_id, references(:sources, on_delete: :restrict), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:media_items, [:source_id])
    create unique_index(:media_items, [:media_id, :source_id])
  end
end
