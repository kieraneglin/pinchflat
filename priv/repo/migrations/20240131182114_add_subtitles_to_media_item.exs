defmodule Pinchflat.Repo.Migrations.AddSubtitleFilepathsToMediaItem do
  use Ecto.Migration

  def change do
    alter table(:media_items) do
      add :subtitle_filepaths, {:array, {:array, :string}}, default: []
    end
  end
end
