defmodule Pinchflat.Repo.Migrations.AddPredictedMediaFilepathToMediaItems do
  use Ecto.Migration

  def change do
    alter table(:media_items) do
      add :predicted_media_filepath, :string
    end
  end
end
