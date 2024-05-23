defmodule Pinchflat.Repo.Migrations.ChangeMediaItemsSearchIndexTokenizer do
  use Ecto.Migration

  def up do
    # These all need to run as part of separate `execute` blocks. Do NOT ask me why.
    execute "DROP TRIGGER media_items_search_index_insert;"
    execute "DROP TRIGGER media_items_search_index_update;"
    execute "DROP TRIGGER media_items_search_index_delete;"
    execute "DROP TABLE media_items_search_index;"

    execute """
      CREATE VIRTUAL TABLE media_items_search_index USING fts5(
        title,
        description,
        tokenize=trigram
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

    # Fully re-index the media_items table
    execute """
      INSERT INTO media_items_search_index(rowid, title, description)
      SELECT id, title, description FROM media_items;
    """
  end

  def down do
    execute "DROP TABLE media_items_search_index;"
  end
end
