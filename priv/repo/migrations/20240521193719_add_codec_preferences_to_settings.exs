defmodule Pinchflat.Repo.Migrations.AddCodecPreferencesToSettings do
  use Ecto.Migration

  def change do
    alter table(:settings) do
      add :video_codec_preference, {:array, :string}, default: []
      add :audio_codec_preference, {:array, :string}, default: []
    end
  end
end
