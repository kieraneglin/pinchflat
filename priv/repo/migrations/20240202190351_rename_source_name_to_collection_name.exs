defmodule Pinchflat.Repo.Migrations.RenameSourceNameToCollectionName do
  use Ecto.Migration

  def change do
    rename table(:sources), :name, to: :collection_name

    alter table(:sources) do
      add :friendly_name, :string
    end
  end
end
