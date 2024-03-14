defmodule Pinchflat.Repo.Migrations.AddNfoFilepathToMediaItem do
  use Ecto.Migration

  def change do
    alter table(:media_items) do
      add :nfo_filepath, :string
    end
  end
end
