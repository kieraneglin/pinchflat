defmodule Pinchflat.Repo.Migrations.AddNotNullToFriendlyName do
  use Ecto.Migration

  def change do
    alter table(:sources) do
      remove :friendly_name, :string
    end

    alter table(:sources) do
      add :friendly_name, :string, null: false
    end
  end
end
