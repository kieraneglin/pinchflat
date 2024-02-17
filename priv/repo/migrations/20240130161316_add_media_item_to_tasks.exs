defmodule Pinchflat.Repo.Migrations.AddMediaItemToTasks do
  use Ecto.Migration

  def change do
    alter table(:tasks) do
      # `restrict` because we need to be sure to delete pending tasks when a media item is deleted
      add :media_item_id, references(:media_items, on_delete: :restrict), null: true
    end

    create index(:tasks, [:media_item_id])
  end
end
