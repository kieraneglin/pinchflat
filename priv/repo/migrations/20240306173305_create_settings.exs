defmodule Pinchflat.Repo.Migrations.CreateSettings do
  use Ecto.Migration

  def change do
    create table(:settings) do
      add :name, :string, null: false
      add :value, :string, null: false
      add :datatype, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:settings, [:name])
  end
end
