defmodule Pinchflat.Repo.Migrations.AddImageAttrsToSourceMetadata do
  use Ecto.Migration

  def change do
    alter table(:source_metadata) do
      add :fanart_filepath, :string
      add :poster_filepath, :string
      add :banner_filepath, :string
    end
  end
end
