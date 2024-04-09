defmodule Pinchflat.Repo.Migrations.AddRedownloadedFields do
  use Ecto.Migration

  def change do
    alter table(:media_profiles) do
      add :redownload_delay_days, :integer
    end

    alter table(:media_items) do
      add :redownloaded_at, :utc_datetime
    end
  end
end
