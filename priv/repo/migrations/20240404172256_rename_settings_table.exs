defmodule Pinchflat.Repo.Migrations.RenameSettingsBackupTable do
  use Ecto.Migration

  def change do
    rename table(:settings), to: table(:settings_backup)
  end
end
