defmodule PinchflatWeb.Helpers.PaginationHelpers do
  alias Pinchflat.Repo
  alias Pinchflat.Utils.NumberUtils

  # TODO: test
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

  # TODO: test
  def update_page_number(current_page, direction, total_pages) do
    updated_page =
      case to_string(direction) do
        "inc" -> current_page + 1
        "dec" -> current_page - 1
      end

    NumberUtils.clamp(updated_page, 1, total_pages)
  end
end
