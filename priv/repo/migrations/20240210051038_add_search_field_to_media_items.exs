defmodule Pinchflat.Repo.Migrations.AddSearchFieldToMediaItems do
  use Ecto.Migration

  def up do
    # These all need to run as part of separate `execute` blocks. Do NOT ask me why.
    execute """
      CREATE VIRTUAL TABLE media_items_search_index USING fts5(
        title,
        description,
        tokenize=porter
      );
    """

    execute """
      CREATE TRIGGER media_items_search_index_insert AFTER INSERT ON media_items BEGIN
        INSERT INTO media_items_search_index(
          rowid,
          title,
          description
        )
        VALUES(
          new.id,
          new.title,
          new.description
        );
      END;
    """

    execute """
      CREATE TRIGGER media_items_search_index_update AFTER UPDATE ON media_items BEGIN
        UPDATE media_items_search_index SET
          title = new.title,
          description = new.description
        WHERE
          rowid = old.id;
      END;
    """

    execute """
      CREATE TRIGGER media_items_search_index_delete AFTER DELETE ON media_items BEGIN
        DELETE FROM media_items_search_index WHERE rowid = old.id;
      END;
    """
  end

  def down do
    execute """
      DROP TABLE media_items_search_index;
    """
  end
end
