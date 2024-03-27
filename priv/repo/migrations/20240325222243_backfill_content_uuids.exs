defmodule Pinchflat.Repo.Migrations.BackfillContentUuids do
  use Ecto.Migration

  def up do
    execute("UPDATE sources SET uuid = gen_random_uuid() WHERE uuid IS NULL")
    execute("UPDATE media_items SET uuid = gen_random_uuid() WHERE uuid IS NULL")
  end

  def down do
    execute("UPDATE sources SET uuid = NULL")
    execute("UPDATE media_items SET uuid = NULL")
  end
end
