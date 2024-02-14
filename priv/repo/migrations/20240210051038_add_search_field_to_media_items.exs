defmodule Pinchflat.Repo.Migrations.AddSearchFieldToMediaItems do
  use Ecto.Migration

  def up do
    execute """
      ALTER TABLE media_items
        ADD COLUMN searchable tsvector
        GENERATED ALWAYS AS (
          setweight(to_tsvector('english', coalesce(title, '')), 'A') ||
          setweight(to_tsvector('english', coalesce(description, '')), 'B')
        ) STORED;
    """

    execute """
      CREATE INDEX media_items_searchable_idx ON media_items USING gin(searchable);
    """
  end

  def down do
    execute """
      DROP INDEX media_items_searchable_idx;
    """

    alter table(:media_items) do
      remove :searchable
    end
  end
end
