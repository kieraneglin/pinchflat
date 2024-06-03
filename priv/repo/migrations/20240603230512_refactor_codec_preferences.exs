defmodule Pinchflat.Repo.Migrations.RefactorCodecPreferences do
  use Ecto.Migration

  def change do
    alter table(:settings) do
      remove :video_codec_preference, {:array, :string}, default: []
      remove :audio_codec_preference, {:array, :string}, default: []
    end

    alter table(:settings) do
      add :video_codec_preference, :string, default: "avc"
      add :audio_codec_preference, :string, default: "m4a"
    end
  end
end
