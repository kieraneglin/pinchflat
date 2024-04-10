defmodule Pinchflat.Repo.Migrations.AddAppriseVersionToSettings do
  use Ecto.Migration

  def change do
    alter table(:settings) do
      add :apprise_version, :string
    end
  end
end
