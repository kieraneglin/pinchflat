defmodule Pinchflat.Repo.Migrations.ReReAddSourceUniquenessIndex do
  use Ecto.Migration

  def change do
    create unique_index(:sources, [:collection_id, :media_profile_id, :title_filter_regex])
  end
end
