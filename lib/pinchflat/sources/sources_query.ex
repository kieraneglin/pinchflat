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

  # Prefixes:
  # - for_* - belonging to a certain record
  # - join_* - for joining on a certain record
  # - with_* - for filtering based on full, concrete attributes
  # - matching_* - for filtering based on partial attributes (e.g. LIKE, regex, full-text search)
  #
  # Suffixes:
  # - _for - the arg passed is an association record

  def new do
    Source
  end

  def for_media_profile(query, media_profile) do
    where(query, [s], s.media_profile_id == ^media_profile.id)
  end
end
