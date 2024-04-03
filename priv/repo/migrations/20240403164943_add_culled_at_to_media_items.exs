defmodule Pinchflat.Repo.Migrations.AddCulledAtToMediaItems do
  use Ecto.Migration

  def change do
    alter table(:media_items) do
      add :culled_at, :utc_datetime
    end
  end
end
