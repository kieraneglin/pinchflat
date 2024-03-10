defmodule Pinchflat.Repo.Migrations.AddUploadedAtToMediaItems do
  use Ecto.Migration

  def change do
    alter table(:media_items) do
      # Setting default to unix epoch so I can enforce not null BUT also easily
      # identify records that were created before this column was added
      add :uploaded_at, :utc_datetime, default: "1970-01-01T00:00:00", null: false
    end
  end
end
