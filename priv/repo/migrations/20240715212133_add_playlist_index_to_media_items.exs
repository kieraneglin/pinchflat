defmodule Pinchflat.Repo.Migrations.AddPlaylistIndexToMediaItems do
  use Ecto.Migration

  def change do
    alter table(:media_items) do
      add :playlist_index, :integer, null: false, default: 0
    end
  end
end
