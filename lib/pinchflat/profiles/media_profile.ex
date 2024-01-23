defmodule Pinchflat.Profiles.MediaProfile do
  @moduledoc """
  A media profile is a set of settings that can be applied to many media sources
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "media_profiles" do
    field :name, :string
    field :output_path_template, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(media_profile, attrs) do
    media_profile
    |> cast(attrs, [:name, :output_path_template])
    |> validate_required([:name, :output_path_template])
    |> unique_constraint(:name)
  end
end
