defmodule Pinchflat.Utils.NumberUtilsTest do
  use Pinchflat.DataCase

  alias Pinchflat.Utils.NumberUtils

  describe "clamp/3" do
    test "returns the minimum when the number is less than the minimum" do
      assert NumberUtils.clamp(1, 2, 3) == 2
    end

    test "returns the maximum when the number is greater than the maximum" do
      assert NumberUtils.clamp(4, 2, 3) == 3
    end

    test "returns the number when it is between the minimum and maximum" do
      assert NumberUtils.clamp(2, 1, 3) == 2
    end
  end
end
