defmodule Pinchflat.Repo.Migrations.AddDescriptionToMediaItems do
  use Ecto.Migration

  def change do
    alter table(:media_items) do
      add :description, :text
    end
  end
end
