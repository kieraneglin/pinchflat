defmodule Pinchflat.Repo.Migrations.CreateSourceMetadata do
  use Ecto.Migration

  def change do
    create table(:source_metadata) do
      add :metadata_filepath, :string, null: false
      add :source_id, references(:sources, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:source_metadata, [:source_id])
  end
end
