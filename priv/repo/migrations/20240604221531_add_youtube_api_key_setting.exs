defmodule Pinchflat.Repo.Migrations.AddYoutubeApiKeySetting do
  use Ecto.Migration

  def change do
    alter table(:settings) do
      add :youtube_api_key, :string
    end
  end
end
