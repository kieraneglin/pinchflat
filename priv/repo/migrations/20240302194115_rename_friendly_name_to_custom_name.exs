defmodule Pinchflat.Repo.Migrations.RenameFriendlyNameToCustomName do
  use Ecto.Migration

  def change do
    rename table(:sources), :friendly_name, to: :custom_name
  end
end
