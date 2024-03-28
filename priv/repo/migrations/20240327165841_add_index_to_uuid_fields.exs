defmodule Pinchflat.Repo.Migrations.AddIndexToUuidFields do
  use Ecto.Migration

  def change do
    create unique_index(:sources, [:uuid])
    create unique_index(:media_items, [:uuid])
  end
end
