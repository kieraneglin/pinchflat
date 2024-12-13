defmodule PinchflatWeb.Helpers.PaginationHelpersTest do
  use Pinchflat.DataCase
  import Pinchflat.SourcesFixtures

  alias Pinchflat.Sources.Source
  alias PinchflatWeb.Helpers.PaginationHelpers

  describe "get_pagination_attributes/3" do
    test "returns the correct pagination attributes" do
      source_fixture()
      query = from(s in Source, select: s.id)
      page = 1
      records_per_page = 10

      pagination_attributes = PaginationHelpers.get_pagination_attributes(query, page, records_per_page)

      assert pagination_attributes.page == 1
      assert pagination_attributes.total_pages == 1
      assert pagination_attributes.total_record_count == 1
      assert pagination_attributes.limit == 10
      assert pagination_attributes.offset == 0
    end

    test "returns the correct pagination attributes when there are multiple pages" do
      source_fixture()
      source_fixture()

      query = from(s in Source, select: s.id)
      page = 1
      records_per_page = 1

      pagination_attributes = PaginationHelpers.get_pagination_attributes(query, page, records_per_page)

      assert pagination_attributes.page == 1
      assert pagination_attributes.total_pages == 2
      assert pagination_attributes.total_record_count == 2
      assert pagination_attributes.limit == 1
      assert pagination_attributes.offset == 0
    end

    test "returns the correct attributes when on a page other than the first" do
      source_fixture()
      source_fixture()

      query = from(s in Source, select: s.id)
      page = 2
      records_per_page = 1

      pagination_attributes = PaginationHelpers.get_pagination_attributes(query, page, records_per_page)

      assert pagination_attributes.page == 2
      assert pagination_attributes.total_pages == 2
      assert pagination_attributes.total_record_count == 2
      assert pagination_attributes.limit == 1
      assert pagination_attributes.offset == 1
    end
  end

  describe "update_page_number/3" do
    test "increments the page number" do
      current_page = 1
      total_pages = 2

      updated_page = PaginationHelpers.update_page_number(current_page, :inc, total_pages)

      assert updated_page == 2
    end

    test "decrements the page number" do
      current_page = 2
      total_pages = 2

      updated_page = PaginationHelpers.update_page_number(current_page, :dec, total_pages)

      assert updated_page == 1
    end

    test "doesn't overflow the page number" do
      current_page = 2
      total_pages = 2

      updated_page = PaginationHelpers.update_page_number(current_page, :inc, total_pages)

      assert updated_page == 2
    end

    test "doesn't underflow the page number" do
      current_page = 1
      total_pages = 2

      updated_page = PaginationHelpers.update_page_number(current_page, :dec, total_pages)

      assert updated_page == 1
    end
  end
end
