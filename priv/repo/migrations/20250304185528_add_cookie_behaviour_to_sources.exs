defmodule Pinchflat.Repo.Migrations.AddCookieBehaviourToSources do
  use Ecto.Migration

  def change do
    alter table(:sources) do
      add :cookie_behaviour, :string, null: false, default: "disabled"
    end

    execute(
      "UPDATE sources SET cookie_behaviour = 'all_operations' WHERE use_cookies = TRUE",
      "UPDATE sources SET use_cookies = TRUE WHERE cookie_behaviour = 'all_operations'"
    )

    alter table(:sources) do
      remove :use_cookies, :boolean, null: false, default: false
    end
  end
end
