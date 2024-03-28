defmodule Pinchflat.Repo.Migrations.AddSponsorblockToMediaProfiles do
  use Ecto.Migration

  def change do
    alter table(:media_profiles) do
      add :sponsorblock_behaviour, :string, default: "disabled"
      add :sponsorblock_categories, {:array, :string}, default: []
    end
  end
end
