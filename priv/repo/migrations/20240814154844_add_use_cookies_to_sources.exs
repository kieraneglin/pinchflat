defmodule Pinchflat.Repo.Migrations.AddUseCookiesToSources do
  use Ecto.Migration

  def change do
    alter table(:sources) do
      add :use_cookies, :boolean, default: true, null: false
    end
  end
end
