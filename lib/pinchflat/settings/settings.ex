defmodule Pinchflat.Settings do
  @moduledoc """
  The Settings context.
  """
  import Ecto.Query, warn: false

  alias Pinchflat.Repo
  alias Pinchflat.Settings.Setting

  @doc """
  Returns the only setting record. It _should_ be impossible
  to create or delete this record, so it's assertive about
  assuming it's the only one.

  Returns %Setting{}
  """
  def record do
    Setting
    |> limit(1)
    |> Repo.one()
  end

  @doc """
  Updates a setting, returning the new value.
  Is setup to take a keyword list argument so you
  can call it like `Settings.set(onboarding: true)`

  Returns {:ok, value} | {:error, :invalid_key} | {:error, %Ecto.Changeset{}}
  """
  def set([{attr, value}]) do
    record()
    |> Setting.changeset(%{attr => value})
    |> Repo.update()
    |> case do
      {:ok, %{^attr => _}} -> {:ok, value}
      {:ok, _} -> {:error, :invalid_key}
      {:error, changeset} -> {:error, changeset}
    end
  end

  @doc """
  Gets the value of a setting.

  Returns {:ok, value} | {:error, :invalid_key}
  """
  def get(name) do
    case Map.fetch(record(), name) do
      {:ok, value} -> {:ok, value}
      :error -> {:error, :invalid_key}
    end
  end

  @doc """
  Gets the value of a setting, raising if it doesn't exist.

  Returns value
  """
  def get!(name) do
    case get(name) do
      {:ok, value} -> value
      {:error, _} -> raise "Setting `#{name}` not found"
    end
  end
end
