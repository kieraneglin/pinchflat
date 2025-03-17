defmodule Pinchflat.Repo.Migrations.AddRestrictFilenamesToSettings do
  use Ecto.Migration

  def change do
    alter table(:settings) do
      add :restrict_filenames, :boolean, default: false
    end
  end
end
