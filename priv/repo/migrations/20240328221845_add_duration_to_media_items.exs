defmodule Pinchflat.Repo.Migrations.AddDurationToMediaItems do
  use Ecto.Migration

  def change do
    alter table(:media_items) do
      add :duration_seconds, :integer
    end
  end
end
