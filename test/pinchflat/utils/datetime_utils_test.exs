defmodule Pinchflat.Utils.DatetimeUtilsTest do
  use Pinchflat.DataCase

  alias Pinchflat.Utils.DatetimeUtils

  describe "date_to_datetime/1" do
    test "converts a Date to a DateTime" do
      date = ~D[2022-01-01]
      datetime = DatetimeUtils.date_to_datetime(date)

      assert datetime == ~U[2022-01-01 00:00:00Z]
    end
  end
end
