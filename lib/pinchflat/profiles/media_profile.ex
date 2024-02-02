defmodule Pinchflat.Profiles.MediaProfile do
  @moduledoc """
  A media profile is a set of settings that can be applied to many media sources
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Pinchflat.MediaSource.Source

  @allowed_fields ~w(
    name
    output_path_template
    download_subs
    download_auto_subs
    embed_subs
    sub_langs
  )a

  @required_fields ~w(name output_path_template)a

  schema "media_profiles" do
    field :name, :string
    field :output_path_template, :string
    field :download_subs, :boolean, default: true
    field :download_auto_subs, :boolean, default: true
    field :embed_subs, :boolean, default: true
    field :sub_langs, :string, default: "en"

    has_many :sources, Source

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(media_profile, attrs) do
    media_profile
    |> cast(attrs, @allowed_fields)
    |> validate_required(@required_fields)
    |> unique_constraint(:name)
  end
end
