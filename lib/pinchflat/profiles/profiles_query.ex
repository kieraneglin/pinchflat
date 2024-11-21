defmodule Pinchflat.Profiles.ProfilesQuery do
  @moduledoc """
  Query helpers for the Profiles context.

  These methods are made to be one-ish liners used
  to compose queries. Each method should strive to do
  _one_ thing. These don't need to be tested as
  they are just building blocks for other functionality
  which, itself, will be tested.
  """
  import Ecto.Query, warn: false

  alias Pinchflat.Profiles.MediaProfile

  # This allows the module to be aliased and query methods to be used
  # all in one go
  # usage: use Pinchflat.Profiles.ProfilesQuery
  defmacro __using__(_opts) do
    quote do
      import Ecto.Query, warn: false

      alias unquote(__MODULE__)
    end
  end

  def new do
    MediaProfile
  end
end
