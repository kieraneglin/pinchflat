defmodule Pinchflat.Settings do
  @moduledoc """
  The Settings context.
  """

  import Ecto.Query, warn: false
  alias Pinchflat.Repo

  alias Pinchflat.Settings.Setting

  @doc """
  Returns the list of settings.

  Returns [%Setting{}, ...]
  """
  def list_settings do
    Repo.all(Setting)
  end

  @doc """
  Creates or updates a setting, returning the parsed value.
  Raises if an unsupported datatype is used.

  Returns value in type of `Ecto.Enum.mappings(Setting, :datatype)`
  """
  def set!(name, value) do
    set!(name, value, infer_datatype(value))
  end

  def set!(name, value, datatype) do
    # Only create if doesn't exist
    case Repo.get_by(Setting, name: to_string(name)) do
      nil -> create_setting!(name, value, datatype)
      setting -> update_setting!(setting, value, datatype)
    end
  end

  @doc """
  Gets the parsed value of a setting. Raises if the setting does not exist.

  Returns value in type of `Ecto.Enum.mappings(Setting, :datatype)`
  """
  def get!(name) do
    Setting
    |> Repo.get_by!(name: to_string(name))
    |> read_setting()
  end

  defp change_setting(setting, attrs) do
    Setting.changeset(setting, attrs)
  end

  defp create_setting!(name, value, datatype) do
    %Setting{}
    |> change_setting(%{name: to_string(name), value: to_string(value), datatype: datatype})
    |> Repo.insert!()
    |> read_setting()
  end

  defp update_setting!(setting, value, datatype) do
    setting
    |> change_setting(%{value: to_string(value), datatype: datatype})
    |> Repo.update!()
    |> read_setting()
  end

  defp read_setting(%{value: value, datatype: :string}), do: value
  defp read_setting(%{value: value, datatype: :boolean}), do: value in ["true", "t", "1"]
  defp read_setting(%{value: value, datatype: :integer}), do: String.to_integer(value)
  defp read_setting(%{value: value, datatype: :float}), do: String.to_float(value)

  defp infer_datatype(value) when is_boolean(value), do: :boolean
  defp infer_datatype(value) when is_integer(value), do: :integer
  defp infer_datatype(value) when is_float(value), do: :float
  defp infer_datatype(value) when is_binary(value), do: :string
end
