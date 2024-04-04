defmodule Pinchflat.Repo.Migrations.CreateNewSettings do
  use Ecto.Migration

  def up do
    create table(:settings) do
      add :onboarding, :boolean, default: true, null: false
      add :pro_enabled, :boolean, default: false, null: false
      add :yt_dlp_version, :string
    end

    # Make an initial record because this will be the only one ever inserted
    execute "INSERT INTO settings (onboarding, pro_enabled, yt_dlp_version) VALUES (true, false, NULL)"

    # Set the value of onboarding to the previous version set in `settings_backup`
    execute """
      UPDATE settings
      SET onboarding = COALESCE((SELECT value = 'true' FROM settings_backup WHERE name = 'onboarding'), true)
    """

    execute """
      UPDATE settings
      SET pro_enabled = COALESCE((SELECT value = 'true' FROM settings_backup WHERE name = 'pro_enabled'), false)
    """
  end

  def down do
    drop table(:settings)
  end
end
