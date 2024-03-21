defmodule Pinchflat.Repo.Migrations.RemoveUniqueIndexFromSources do
  use Ecto.Migration

  def change do
    drop unique_index(:sources, [:collection_id, :media_profile_id])
  end
end
