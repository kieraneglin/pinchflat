defmodule Pinchflat.Repo.Migrations.AddAppriseServersToSettings do
  use Ecto.Migration

  def change do
    alter table(:settings) do
      add :apprise_server, :string
    end
  end
end
