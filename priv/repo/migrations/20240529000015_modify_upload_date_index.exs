defmodule Pinchflat.Repo.Migrations.ModifyUploadDateIndex do
  use Ecto.Migration

  def change do
    drop index("media_items", [:upload_date])
    create index("media_items", [:uploaded_at])
  end
end
