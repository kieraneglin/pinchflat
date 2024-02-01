defmodule Pinchflat.Repo.Migrations.AddSubtitleOptionsToMediaProfiles do
  use Ecto.Migration

  def change do
    alter table(:media_profiles) do
      add :download_subs, :boolean, default: true, null: false
      add :download_auto_subs, :boolean, default: true, null: false
      add :embed_subs, :boolean, default: true, null: false
      add :sub_langs, :string, default: "en", null: false
    end
  end
end
