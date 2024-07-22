defmodule Pinchflat.Repo.Migrations.AddMarkedForDeletionAtToSources do
  use Ecto.Migration

  def change do
    alter table(:sources) do
      add :marked_for_deletion_at, :utc_datetime
    end

    alter table(:media_profiles) do
      add :marked_for_deletion_at, :utc_datetime
    end
  end
end
