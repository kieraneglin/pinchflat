defmodule Pinchflat.Repo.Migrations.AddMediaContainerToMediaProfiles do
  use Ecto.Migration

  def change do
    alter table(:media_profiles) do
      add :media_container, :string
    end
  end
end
