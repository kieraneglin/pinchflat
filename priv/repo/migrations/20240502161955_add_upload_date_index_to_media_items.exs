defmodule Pinchflat.Repo.Migrations.AddUploadDateIndexToMediaItems do
  use Ecto.Migration

  def change do
    alter table(:media_items) do
      add :upload_date_index, :integer, null: false, default: 0
    end

    create index("media_items", [:upload_date])
  end
end
