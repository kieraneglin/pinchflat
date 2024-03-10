defmodule Pinchflat.Repo.Migrations.AddShortFormToMediaItems do
  use Ecto.Migration

  def change do
    alter table(:media_items) do
      add :short_form_content, :boolean, null: false, default: false
    end
  end
end
