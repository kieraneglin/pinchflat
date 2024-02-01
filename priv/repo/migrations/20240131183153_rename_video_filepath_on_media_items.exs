defmodule Pinchflat.Repo.Migrations.RenameVideoFilepathOnMediaItems do
  use Ecto.Migration

  def change do
    rename table(:media_items), :video_filepath, to: :media_filepath
  end
end
