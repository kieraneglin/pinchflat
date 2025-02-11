defmodule Pinchflat.Repo.Migrations.AddLastErrorToMediaItem do
  use Ecto.Migration

  def change do
    alter table(:media_items) do
      add :last_error, :string
    end
  end
end
