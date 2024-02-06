defmodule Pinchflat.Repo.Migrations.AddReleaseTypeBehaviourToMediaProfiles do
  use Ecto.Migration

  def change do
    alter table(:media_profiles) do
      add :shorts_behaviour, :string, null: false, default: "include"
      add :livestream_behaviour, :string, null: false, default: "include"
    end
  end
end
