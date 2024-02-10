defmodule Pinchflat.Repo.Migrations.AddIndexingAttributesToMediaItems do
  use Ecto.Migration

  def change do
    alter table(:media_items) do
      add :livestream, :boolean, default: false, null: false
      add :original_url, :string, null: false
    end
  end
end
