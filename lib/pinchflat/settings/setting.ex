defmodule Pinchflat.Settings.Setting do
  @moduledoc """
  The Setting schema.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @allowed_fields [
    :onboarding,
    :pro_enabled,
    :yt_dlp_version,
    :apprise_version,
    :apprise_server,
    :video_codec_preference,
    :audio_codec_preference
  ]

  @required_fields ~w(
    onboarding
    pro_enabled
  )a

  schema "settings" do
    field :onboarding, :boolean, default: true
    field :pro_enabled, :boolean, default: false
    field :yt_dlp_version, :string
    field :apprise_version, :string
    field :apprise_server, :string

    field :video_codec_preference, {:array, :string}, default: []
    field :audio_codec_preference, {:array, :string}, default: []
    field :video_codec_preference_string, :string, virtual: true
    field :audio_codec_preference_string, :string, virtual: true
  end

  @doc false
  def changeset(setting, attrs) do
    setting
    |> cast(attrs, @allowed_fields)
    |> validate_required(@required_fields)
  end
end
