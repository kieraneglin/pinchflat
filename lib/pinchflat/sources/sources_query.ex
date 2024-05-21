defmodule Pinchflat.Sources.SourcesQuery do
  @moduledoc """
  Query helpers for the Sources context.

  These methods are made to be one-ish liners used
  to compose queries. Each method should strive to do
  _one_ thing. These don't need to be tested as
  they are just building blocks for other functionality
  which, itself, will be tested.
  """
  import Ecto.Query, warn: false

  alias Pinchflat.Sources.Source

  # This allows the module to be aliased and query methods to be used
  # all in one go
  # usage: use Pinchflat.Sources.SourcesQuery
  defmacro __using__(_opts) do
    quote do
      import Ecto.Query, warn: false

      alias unquote(__MODULE__)
    end
  end

  def new do
    Source
  end

  def for_media_profile(media_profile_id) when is_integer(media_profile_id) do
    dynamic([s], s.media_profile_id == ^media_profile_id)
  end

  def for_media_profile(media_profile) do
    dynamic([s], s.media_profile_id == ^media_profile.id)
  end
end
