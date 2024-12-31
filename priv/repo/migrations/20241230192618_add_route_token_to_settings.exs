defmodule Pinchflat.Repo.Migrations.AddRouteTokenToSettings do
  use Ecto.Migration

  def change do
    alter table(:settings) do
      add :route_token, :string, null: false, default: "tmp-token"
    end

    execute "UPDATE settings SET route_token = gen_random_uuid();", "SELECT 1;"
  end
end
