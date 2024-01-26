defmodule Pinchflat.Repo.Migrations.AddIndexFrequencyToChannels do
  use Ecto.Migration

  def change do
    alter table(:channels) do
      add :index_frequency_minutes, :integer, default: 60 * 24, null: false
    end
  end
end
