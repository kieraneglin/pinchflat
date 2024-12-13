defmodule PinchflatWeb.Helpers.PaginationHelpers do
  @moduledoc """
  Methods for working with pagination, usually in the context of LiveViews or LiveComponents.

  These methods are fairly simple, but they're commonly repeated across different Live entities
  """

  alias Pinchflat.Repo
  alias Pinchflat.Utils.NumberUtils

  @doc """
  Given a query, a page number, and a number of records per page, returns a map of pagination attributes.

  Returns map()
  """
  def get_pagination_attributes(query, page, records_per_page) do
    total_record_count = Repo.aggregate(query, :count, :id)
    total_pages = max(ceil(total_record_count / records_per_page), 1)
    clamped_page = NumberUtils.clamp(page, 1, total_pages)

    %{
      page: clamped_page,
      total_pages: total_pages,
      total_record_count: total_record_count,
      limit: records_per_page,
      offset: (clamped_page - 1) * records_per_page
    }
  end

  @doc """
  Given a current page number, a direction to move in, and the total number of pages, returns the updated page number.
  The updated page number is clamped to the range [1, total_pages].

  Returns integer()
  """
  def update_page_number(current_page, direction, total_pages) do
    updated_page =
      case to_string(direction) do
        "inc" -> current_page + 1
        "dec" -> current_page - 1
      end

    NumberUtils.clamp(updated_page, 1, total_pages)
  end
end
