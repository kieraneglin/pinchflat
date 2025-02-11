defmodule Pinchflat.Repo.Migrations.AddLastErrorToMediaItem do
  use Ecto.Migration

  def change do
    alter table(:media_items) do
      add :last_error, :string
    end

    execute "CREATE INDEX media_items_last_error_index ON media_items (last_error);",
            "DROP INDEX media_items_last_error_index;"
  end
end
