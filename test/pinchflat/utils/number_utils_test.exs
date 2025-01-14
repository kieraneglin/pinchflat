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

  describe "human_byte_size/1" do
    test "converts byte size to human readable format" do
      assert NumberUtils.human_byte_size(1024) == {1, "KB"}
      assert NumberUtils.human_byte_size(1024 * 1024) == {1, "MB"}
      assert NumberUtils.human_byte_size(1024 * 1024 * 1024) == {1, "GB"}
      assert NumberUtils.human_byte_size(1024 * 1024 * 1024 * 1024) == {1, "TB"}
      assert NumberUtils.human_byte_size(1024 * 1024 * 1024 * 1024 * 1024) == {1, "PB"}
      assert NumberUtils.human_byte_size(1024 * 1024 * 1024 * 1024 * 1024 * 1024) == {1, "EB"}
      assert NumberUtils.human_byte_size(1024 * 1024 * 1024 * 1024 * 1024 * 1024 * 1024) == {1, "ZB"}
      assert NumberUtils.human_byte_size(1024 * 1024 * 1024 * 1024 * 1024 * 1024 * 1024 * 1024) == {1, "YB"}
    end

    test "returns the number when it is less than 1024" do
      assert NumberUtils.human_byte_size(512) == {512, "B"}
    end

    test "optionally takes a precision" do
      assert NumberUtils.human_byte_size(1234 * 1024, precision: 0) == {1, "MB"}
      assert NumberUtils.human_byte_size(1234 * 1024, precision: 1) == {1.2, "MB"}
      assert NumberUtils.human_byte_size(1234 * 1024, precision: 2) == {1.21, "MB"}
    end

    test "handles 0's well" do
      assert NumberUtils.human_byte_size(0) == {0, "B"}
    end

    test "handles nil well" do
      assert NumberUtils.human_byte_size(nil) == {0, "B"}
    end
  end

  describe "add_jitter/2" do
    test "returns 0 when the number is less than or equal to 0" do
      assert NumberUtils.add_jitter(0) == 0
      assert NumberUtils.add_jitter(-1) == 0
    end

    test "returns the number with jitter added" do
      assert NumberUtils.add_jitter(100) in 100..150
    end

    test "optionally takes a jitter percentage" do
      assert NumberUtils.add_jitter(100, 0.1) in 90..110
      assert NumberUtils.add_jitter(100, 0.5) in 50..150
      assert NumberUtils.add_jitter(100, 1) in 0..200
    end
  end
end
