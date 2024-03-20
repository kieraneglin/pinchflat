defmodule Pinchflat.Repo.Migrations.AddSourcePhotosFields do
  use Ecto.Migration

  def change do
    alter table(:sources) do
      add :fanart_filepath, :string
      add :poster_filepath, :string
      add :banner_filepath, :string
    end

    alter table(:media_profiles) do
      add :download_source_images, :boolean, default: false, null: false
    end
  end
end
