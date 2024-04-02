defmodule Pinchflat.Media.MediaQuery do
  @moduledoc """
  Query helpers for the Media context.

  These methods are made to be one-ish liners used
  to compose queries for media items. Each method should
  strive to do _one_ thing. These don't need to be tested
  as they are just building blocks for other functionality
  which, itself, will be tested.

  ALSO, this is me trying something new. If I like it,
  I'll refactor other contexts to use this pattern.
  """
  import Ecto.Query, warn: false

  alias Pinchflat.Media.MediaItem

  # Prefixes:
  # - for_* - belonging to a certain record
  # - with_* - for filtering based on full, concrete attributes
  # - matching_* - for filtering based on partial attributes (e.g. LIKE, regex, full-text search)
  #
  # Suffixes:
  # - _for - the arg passed is an association record

  def new do
    MediaItem
  end

  def for_source(query, source) do
    where(query, [mi], mi.source_id == ^source.id)
  end

  def with_id(query, id) do
    where(query, [mi], mi.id == ^id)
  end

  def with_media_ids(query, media_ids) do
    where(query, [mi], mi.media_id in ^media_ids)
  end

  def with_media_filepath(query) do
    where(query, [mi], not is_nil(mi.media_filepath))
  end

  def with_no_media_filepath(query) do
    where(query, [mi], is_nil(mi.media_filepath))
  end

  def with_upload_date_after(query, nil), do: query

  def with_upload_date_after(query, date) do
    where(query, [mi], mi.upload_date >= ^date)
  end

  def with_no_prevented_download(query) do
    where(query, [mi], mi.prevent_download == false)
  end

  def matching_title_regex(query, nil), do: query

  def matching_title_regex(query, regex) do
    where(query, [mi], fragment("regexp_like(?, ?)", mi.title, ^regex))
  end

  def matching_search_term(query, nil), do: query

  def matching_search_term(query, term) do
    from(mi in query,
      join: mi_search_index in assoc(mi, :media_items_search_index),
      where: fragment("media_items_search_index MATCH ?", ^term),
      select_merge: %{
        matching_search_term:
          fragment("""
            coalesce(snippet(media_items_search_index, 0, '[PF_HIGHLIGHT]', '[/PF_HIGHLIGHT]', '...', 20), '') ||
            ' ' ||
            coalesce(snippet(media_items_search_index, 1, '[PF_HIGHLIGHT]', '[/PF_HIGHLIGHT]', '...', 20), '')
          """)
      },
      order_by: [desc: fragment("rank")]
    )
  end

  # NOTE: this method breaks the contract set by other methods in that it
  # takes a media_profile struct instead of taking just the attributes it
  # cares about. Consider refactoring but low priority.
  def with_format_preference(query, media_profile) do
    mapped_struct = Map.from_struct(media_profile)

    finders =
      Enum.reduce(mapped_struct, dynamic(true), fn attr, dynamic ->
        case {attr, media_profile} do
          {{:shorts_behaviour, :only}, %{livestream_behaviour: :only}} ->
            dynamic(
              [mi],
              ^dynamic and (mi.livestream == true or mi.short_form_content == true)
            )

          # Technically redundant, but makes the other clauses easier to parse
          # (redundant because this condition is the same as the condition above, just flipped)
          {{:livestream_behaviour, :only}, %{shorts_behaviour: :only}} ->
            dynamic

          {{:shorts_behaviour, :only}, _} ->
            dynamic([mi], ^dynamic and mi.short_form_content == true)

          {{:livestream_behaviour, :only}, _} ->
            dynamic([mi], ^dynamic and mi.livestream == true)

          {{:shorts_behaviour, :exclude}, %{livestream_behaviour: lb}} when lb != :only ->
            dynamic([mi], ^dynamic and mi.short_form_content == false)

          {{:livestream_behaviour, :exclude}, %{shorts_behaviour: sb}} when sb != :only ->
            # return records with livestream: false
            dynamic([mi], ^dynamic and mi.livestream == false)

          _ ->
            dynamic
        end
      end)

    where(query, ^finders)
  end
end
