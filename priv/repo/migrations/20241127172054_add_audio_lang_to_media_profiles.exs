defmodule Pinchflat.Repo.Migrations.AddAudioLangToMediaProfiles do
  use Ecto.Migration

  def change do
    alter table(:media_profiles) do
      add :audio_lang, :string
    end
  end
end
