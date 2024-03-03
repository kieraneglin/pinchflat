defmodule Pinchflat.Repo.Migrations.AddMediaSizeToMediaItem do
  use Ecto.Migration

  def change do
    alter table(:media_items) do
      add :media_size_bytes, :integer
    end
  end
end
