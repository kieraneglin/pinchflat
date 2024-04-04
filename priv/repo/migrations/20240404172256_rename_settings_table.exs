defmodule Pinchflat.Repo.Migrations.RenameSettingsTable do
  use Ecto.Migration

  def change do
    rename table(:settings), to: table(:settings_backup)
  end
end
