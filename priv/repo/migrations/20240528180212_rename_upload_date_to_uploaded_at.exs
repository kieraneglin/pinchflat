defmodule Pinchflat.Repo.Migrations.RenameUploadDateToUploadedAt do
  use Ecto.Migration

  def up do
    rename table(:media_items), :upload_date, to: :uploaded_at

    execute """
      UPDATE media_items
      SET uploaded_at = uploaded_at || 'T00:00:00'
    """
  end

  def down do
    rename table(:media_items), :uploaded_at, to: :upload_date

    execute """
      UPDATE media_items
      SET upload_date = DATE(upload_date)
    """
  end
end
