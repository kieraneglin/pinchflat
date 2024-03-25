defmodule Pinchflat.Repo.Migrations.AddUuidToSourceAndMedia do
  use Ecto.Migration

  def change do
    alter table(:sources) do
      add :uuid, :uuid
    end

    alter table(:media_items) do
      add :uuid, :uuid
    end
  end
end
