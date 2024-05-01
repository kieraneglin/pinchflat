defmodule Pinchflat.Utils.StringUtilsTest do
  use ExUnit.Case, async: false

  alias Pinchflat.Utils.StringUtils

  describe "to_kebab_case/1" do
    test "converts a space-delimited string to kebab-case" do
      assert StringUtils.to_kebab_case("hello world") == "hello-world"
    end

    test "converts an underscore-delimited string to kebab-case" do
      assert StringUtils.to_kebab_case("hello_world") == "hello-world"
    end
  end

  describe "random_string/1" do
    test "generates a random string" do
      assert is_binary(StringUtils.random_string())
      assert StringUtils.random_string() != StringUtils.random_string()
    end

    test "has a defined default length" do
      assert String.length(StringUtils.random_string()) == 32
    end

    test "can generate a string of a given length" do
      assert String.length(StringUtils.random_string(64)) == 64
    end
  end

  describe "truncate/2" do
    test "truncates a string to the given length and adds ..." do
      assert StringUtils.truncate("hello world", 5) == "hello..."
    end

    test "breaks on a word boundary" do
      assert StringUtils.truncate("hello world", 7) == "hello..."
    end

    test "does not truncate a string shorter than the given length" do
      assert StringUtils.truncate("hello", 10) == "hello"
    end
  end
end
