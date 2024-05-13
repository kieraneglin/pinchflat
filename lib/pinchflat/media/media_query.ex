defmodule Pinchflat.Media.MediaQuery do
  @moduledoc """
  Query helpers for the Media context.

  These methods are made to be one-ish liners used
  to compose queries. Each method should strive to do
  _one_ thing. These don't need to be tested as
  they are just building blocks for other functionality
  which, itself, will be tested.
  """
  import Ecto.Query, warn: false

  alias Pinchflat.Media.MediaItem

  # TODO: test
  defmacro __using__(_opts) do
    quote do
      import Ecto.Query, warn: false

      alias unquote(__MODULE__)
    end
  end

  # Prefixes:
  # - for_* - belonging to a certain record
  # - join_* - for joining on a certain record
  # - with_*, where_* - for filtering based on full, concrete attributes
  # - matching_* - for filtering based on partial attributes (e.g. LIKE, regex, full-text search)
  #
  # Suffixes:
  # - _for - the arg passed is an association record

  # NOTE: that dyanmic query approach kinda rocked - should refactor in future

  def new do
    MediaItem
  end

  def for_source(query, source_id) when is_integer(source_id) do
    where(query, [mi], mi.source_id == ^source_id)
  end

  def for_source(query, source) do
    where(query, [mi], mi.source_id == ^source.id)
  end

  def join_sources(query) do
    from(mi in query, join: s in assoc(mi, :source), as: :sources)
  end

  def where_past_retention_period(query) do
    query
    |> require_assoc(:source)
    |> where(
      [mi, source],
      fragment("""
      IFNULL(retention_period_days, 0) > 0 AND
      DATETIME('now', '-' || retention_period_days || ' day') > media_downloaded_at
      """)
    )
  end

  def where_past_redownload_delay(query) do
    query
    |> require_assoc(:source)
    |> require_assoc(:media_profile)
    |> where(
      [_mi, _source, _media_profile],
      # Returns media items where the upload_date is at least redownload_delay_days ago AND
      # downloaded_at minus the redownload_delay_days is before the upload date
      fragment("""
        IFNULL(redownload_delay_days, 0) > 0 AND
        DATETIME('now', '-' || redownload_delay_days || ' day') > upload_date AND
        DATETIME(media_downloaded_at, '-' || redownload_delay_days || ' day') < upload_date
      """)
    )
  end

  def where_culling_not_prevented(query) do
    where(query, [mi], mi.prevent_culling == false)
  end

  def where_not_culled(query) do
    where(query, [mi], is_nil(mi.culled_at))
  end

  def where_media_not_redownloaded(query) do
    where(query, [mi], is_nil(mi.media_redownloaded_at))
  end

  def with_id(query, id) do
    where(query, [mi], mi.id == ^id)
  end

  def with_media_ids(query, media_ids) do
    where(query, [mi], mi.media_id in ^media_ids)
  end

  def with_media_downloaded_at(query) do
    where(query, [mi], not is_nil(mi.media_downloaded_at))
  end

  def with_media_filepath(query) do
    where(query, [mi], not is_nil(mi.media_filepath))
  end

  def with_no_media_filepath(query) do
    where(query, [mi], is_nil(mi.media_filepath))
  end

  def with_upload_date_after_source_cutoff(query) do
    query
    |> require_assoc(:source)
    |> where([mi, source], is_nil(source.download_cutoff_date) or mi.upload_date >= source.download_cutoff_date)
  end

  def where_uploaded_on_date(query, date) do
    where(query, [mi], mi.upload_date == ^date)
  end

  def where_download_not_prevented(query) do
    where(query, [mi], mi.prevent_download == false)
  end

  def matching_source_title_regex(query) do
    query
    |> require_assoc(:source)
    |> where(
      [mi, source],
      is_nil(source.title_filter_regex) or fragment("regexp_like(?, ?)", mi.title, source.title_filter_regex)
    )
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

  def with_format_matching_profile_preference(query) do
    query
    |> require_assoc(:media_profile)
    |> where(
      fragment("""
        CASE
          WHEN shorts_behaviour = 'only' AND livestream_behaviour = 'only' THEN
            livestream = true OR short_form_content = true
          WHEN shorts_behaviour = 'only' THEN
            short_form_content = true
          WHEN livestream_behaviour = 'only' THEN
            livestream = true
          WHEN shorts_behaviour = 'exclude' AND livestream_behaviour = 'exclude' THEN
            short_form_content = false AND livestream = false
          WHEN shorts_behaviour = 'exclude' THEN
            short_form_content = false
          WHEN livestream_behaviour = 'exclude' THEN
            livestream = false
          ELSE
            true
        END
      """)
    )
  end

  def where_pending_download(query) do
    query
    |> where_download_not_prevented()
    |> with_no_media_filepath()
    |> with_upload_date_after_source_cutoff()
    |> with_format_matching_profile_preference()
    |> matching_source_title_regex()
  end

  def where_pending_or_downloaded(query) do
    query
    |> where_pending_download()
    |> or_where([mi], not is_nil(mi.media_downloaded_at))
  end

  defp require_assoc(query, identifier) do
    if has_named_binding?(query, identifier) do
      query
    else
      do_require_assoc(query, identifier)
    end
  end

  defp do_require_assoc(query, :source) do
    from(mi in query, join: s in assoc(mi, :source), as: :source)
  end

  defp do_require_assoc(query, :media_profile) do
    query
    |> require_assoc(:source)
    |> join(:inner, [mi, source], mp in assoc(source, :media_profile), as: :media_profile)
  end
end
