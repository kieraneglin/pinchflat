defmodule Pinchflat.Repo.Migrations.AddIndexesForLargeCollections do
  use Ecto.Migration

  def change do
    create index(
             "media_items",
             [
               :source_id,
               :media_filepath,
               :uploaded_at,
               :prevent_download,
               :livestream,
               :short_form_content,
               :title
             ],
             name: "media_items_pending_and_downloaded_index"
           )
  end
end
