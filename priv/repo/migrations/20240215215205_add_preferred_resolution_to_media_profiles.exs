defmodule Pinchflat.Repo.Migrations.AddPreferredResolutionToMediaProfiles do
  use Ecto.Migration

  def change do
    alter table(:media_profiles) do
      add :preferred_resolution, :string, null: false, default: "1080p"
    end
  end
end
