defmodule Pinchflat.Repo.Migrations.AddDescriptionToSource do
  use Ecto.Migration

  def change do
    alter table(:sources) do
      add :description, :string
    end
  end
end
