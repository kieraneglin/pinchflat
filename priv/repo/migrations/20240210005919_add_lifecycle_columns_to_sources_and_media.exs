defmodule Pinchflat.Repo.Migrations.AddLifecycleColumnsToSourcesAndMedia do
  use Ecto.Migration

  def change do
    alter table(:media_items) do
      add :media_downloaded_at, :utc_datetime
      add :details_updated_at, :utc_datetime
    end

    alter table(:sources) do
      add :last_indexed_at, :utc_datetime
    end
  end
end
