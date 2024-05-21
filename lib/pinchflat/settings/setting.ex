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

  @virtual_fields [
    :video_codec_preference_string,
    :audio_codec_preference_string
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
    field :video_codec_preference_string, :string, default: nil, virtual: true
    field :audio_codec_preference_string, :string, default: nil, virtual: true
  end

  @doc false
  def changeset(setting, attrs) do
    setting
    |> cast(attrs, @allowed_fields)
    |> cast(attrs, @virtual_fields, empty_values: [])
    |> convert_codec_preference_strings()
    |> validate_required(@required_fields)
  end

  defp convert_codec_preference_strings(changeset) do
    fields = [
      video_codec_preference_string: :video_codec_preference,
      audio_codec_preference_string: :audio_codec_preference
    ]

    Enum.reduce(fields, changeset, fn {virtual_field, actual_field}, changeset ->
      case get_change(changeset, virtual_field) do
        nil ->
          changeset

        value ->
          new_value =
            value
            |> String.split(">")
            |> Enum.map(&String.trim/1)
            |> Enum.reject(&(String.trim(&1) == ""))
            |> Enum.map(&String.downcase/1)

          put_change(changeset, actual_field, new_value)
      end
    end)
  end
end
