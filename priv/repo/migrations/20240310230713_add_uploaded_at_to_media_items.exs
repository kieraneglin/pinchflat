defmodule Pinchflat.Repo.Migrations.AddUploadedAtToMediaItems do
  use Ecto.Migration

  def change do
    alter table(:media_items) do
      # Setting default to unix epoch so I can enforce not null BUT also easily
      # identify records that were created before this column was added.
      # Not a DateTime because yt-dlp only returns the date
      add :upload_date, :date, default: "1970-01-01", null: false
    end
  end
end
