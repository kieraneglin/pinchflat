defmodule Pinchflat.Repo.Migrations.CreateMediaMetadata do
  use Ecto.Migration

  def change do
    create table(:media_metadata) do
      add :client_response, :json, null: false
      add :media_item_id, references(:media_items, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:media_metadata, [:media_item_id])
  end
end
