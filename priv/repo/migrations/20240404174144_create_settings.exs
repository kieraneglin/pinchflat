defmodule Pinchflat.Repo.Migrations.CreateSettings do
  use Ecto.Migration

  def up do
    create table(:settings) do
      add :onboarding, :boolean, default: false, null: false
      add :pro_enabled, :boolean, default: false, null: false
      add :yt_dlp_version, :string
    end

    # Make an initial record because this will be the only one ever inserted
    execute "INSERT INTO settings (onboarding, pro_enabled, yt_dlp_version) VALUES (false, false, NULL)"
  end

  def down do
    drop table(:settings)
  end
end
