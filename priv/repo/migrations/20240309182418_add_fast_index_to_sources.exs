defmodule Pinchflat.Repo.Migrations.AddFastIndexToSources do
  use Ecto.Migration

  def change do
    alter table(:sources) do
      add :fast_index, :boolean, null: false, default: false
    end
  end
end
