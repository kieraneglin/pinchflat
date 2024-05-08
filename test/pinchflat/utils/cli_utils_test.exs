defmodule Pinchflat.Utils.CliUtilsTest do
  use Pinchflat.DataCase

  alias Pinchflat.Utils.CliUtils

  describe "wrap_cmd/3" do
    test "delegates to System.cmd/3" do
      assert {"output\n", 0} = CliUtils.wrap_cmd("echo", ["output"])
    end
  end

  describe "parse_options/1" do
    test "it converts symbol k-v arg keys to kebab case" do
      assert ["--buffer-size", "1024"] = CliUtils.parse_options(buffer_size: 1024)
    end

    test "it keeps string k-v arg keys untouched" do
      assert ["--under_score", "1024"] = CliUtils.parse_options({"--under_score", 1024})
    end

    test "it converts symbol arg keys to kebab case" do
      assert ["--ignore-errors"] = CliUtils.parse_options(:ignore_errors)
    end

    test "it keeps string arg keys untouched" do
      assert ["-v"] = CliUtils.parse_options("-v")
    end
  end
end
