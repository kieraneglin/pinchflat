defmodule Pinchflat.Repo.Migrations.AddRateLimitSpeedToSettings do
  use Ecto.Migration

  def change do
    alter table(:settings) do
      add :download_throughput_limit, :string
    end
  end
end
