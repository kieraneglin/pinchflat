defmodule Pinchflat.Repo.Migrations.AddDateIndexesToMediaItems do
  use Ecto.Migration

  def change do
    create(index(:media_items, [:media_downloaded_at]))
    create(index(:media_items, [:media_redownloaded_at]))
  end
end
