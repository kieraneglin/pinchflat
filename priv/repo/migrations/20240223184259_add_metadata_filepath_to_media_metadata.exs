defmodule Pinchflat.Repo.Migrations.AddMetadataFilepathToMediaMetadata do
  use Ecto.Migration

  def change do
    alter table(:media_metadata) do
      add :metadata_filepath, :string, null: false
      add :thumbnail_filepath, :string, null: false

      remove :client_response, :json
    end
  end
end
