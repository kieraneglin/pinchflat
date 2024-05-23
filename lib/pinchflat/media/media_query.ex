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

  # This allows the module to be aliased and query methods to be used
  # all in one go
  # usage: use Pinchflat.Media.MediaQuery
  defmacro __using__(_opts) do
    quote do
      import Ecto.Query, warn: false

      alias unquote(__MODULE__)
    end
  end

  def new do
    MediaItem
  end

  def for_source(source_id) when is_integer(source_id), do: dynamic([mi], mi.source_id == ^source_id)
  def for_source(source), do: dynamic([mi], mi.source_id == ^source.id)

  def downloaded, do: dynamic([mi], not is_nil(mi.media_filepath))
  def download_prevented, do: dynamic([mi], mi.prevent_download == true)
  def culling_prevented, do: dynamic([mi], mi.prevent_culling == true)
  def culled, do: dynamic([mi], not is_nil(mi.culled_at))
  def redownloaded, do: dynamic([mi], not is_nil(mi.media_redownloaded_at))

  def upload_date_after_source_cutoff do
    dynamic([mi, source], is_nil(source.download_cutoff_date) or mi.upload_date >= source.download_cutoff_date)
  end

  def format_matching_profile_preference do
    dynamic(
      [mi, source, media_profile],
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

  def matches_source_title_regex do
    dynamic(
      [mi, source],
      is_nil(source.title_filter_regex) or fragment("regexp_like(?, ?)", mi.title, source.title_filter_regex)
    )
  end

  def past_retention_period do
    dynamic(
      [mi, source],
      fragment("""
        IFNULL(retention_period_days, 0) > 0 AND
        DATETIME('now', '-' || retention_period_days || ' day') > media_downloaded_at
      """)
    )
  end

  def past_redownload_delay do
    dynamic(
      [mi, source, media_profile],
      # Returns media items where the upload_date is at least redownload_delay_days ago AND
      # downloaded_at minus the redownload_delay_days is before the upload date
      fragment("""
        IFNULL(redownload_delay_days, 0) > 0 AND
        DATETIME('now', '-' || redownload_delay_days || ' day') > upload_date AND
        DATETIME(media_downloaded_at, '-' || redownload_delay_days || ' day') < upload_date
      """)
    )
  end

  def cullable do
    dynamic(
      [mi, source],
      ^downloaded() and
        ^past_retention_period() and
        not (^culling_prevented())
    )
  end

  def pending do
    dynamic(
      [mi],
      not (^downloaded()) and
        not (^download_prevented()) and
        ^upload_date_after_source_cutoff() and
        ^format_matching_profile_preference() and
        ^matches_source_title_regex()
    )
  end

  def redownloadable do
    dynamic(
      [mi, source],
      ^downloaded() and
        not (^download_prevented()) and
        not (^culled()) and
        not (^redownloaded()) and
        ^past_redownload_delay()
    )
  end

  def matches_search_term(nil), do: dynamic([mi], true)

  def matches_search_term(term) do
    case String.trim(term) do
      "" -> dynamic([mi], true)
      term -> dynamic([mi], fragment("media_items_search_index MATCH ?", ^term))
    end
  end

  def require_assoc(query, identifier) do
    if has_named_binding?(query, identifier) do
      query
    else
      do_require_assoc(query, identifier)
    end
  end

  defp do_require_assoc(query, :media_items_search_index) do
    from(mi in query, join: s in assoc(mi, :media_items_search_index), as: :media_items_search_index)
  end

  defp do_require_assoc(query, :source) do
    from(mi in query, join: s in assoc(mi, :source), as: :source)
  end

  defp do_require_assoc(query, :media_profile) do
    query
    |> require_assoc(:source)
    |> join(:inner, [mi, source], mp in assoc(source, :media_profile), as: :media_profile)
  end

  # This needs to be a non-dynamic query because it alone should control things like
  # ordering and `snippets` for full-text search
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
end
