defmodule Pinchflat.Utils.StringUtilsTest do
  use ExUnit.Case, async: true

  alias Pinchflat.Utils.StringUtils, as: StringUtils

  describe "to_kebab_case/1" do
    test "converts a space-delimited string to kebab-case" do
      assert StringUtils.to_kebab_case("hello world") == "hello-world"
    end

    test "converts an underscore-delimited string to kebab-case" do
      assert StringUtils.to_kebab_case("hello_world") == "hello-world"
    end
  end
end
