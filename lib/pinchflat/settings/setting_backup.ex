defmodule Pinchflat.SettingsBackup.SettingBackup do
  @moduledoc """
  A Setting is a key-value pair with a datatype used to track user-level settings.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "settings_backup" do
    field :name, :string
    field :value, :string
    field :datatype, Ecto.Enum, values: ~w(boolean string integer float)a

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(setting, attrs) do
    setting
    |> cast(attrs, [:name, :value, :datatype])
    |> validate_required([:name, :value, :datatype])
    |> unique_constraint([:name])
  end
end
