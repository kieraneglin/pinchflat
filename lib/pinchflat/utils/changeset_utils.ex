defmodule Pinchflat.Utils.ChangesetUtils do
  @moduledoc """
  Utility methods for working with changesets
  """

  import Ecto.Changeset

  @doc """
  Sets the default value of a field if it is nil by applying the given function.

  Returns %Ecto.Changeset{}.
  """
  def dynamic_default(changeset, key, value_fn) do
    case get_field(changeset, key) do
      nil -> put_change(changeset, key, value_fn.(changeset))
      _ -> changeset
    end
  end
end
