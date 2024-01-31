defmodule Pinchflat.Repo.Migrations.CreateMediaProfiles do
  use Ecto.Migration

  def change do
    create table(:media_profiles) do
      add :name, :string, null: false
      add :output_path_template, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:media_profiles, [:name])
  end
end
