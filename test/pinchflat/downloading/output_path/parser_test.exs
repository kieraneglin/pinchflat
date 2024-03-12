defmodule Pinchflat.Downloading.OutputPath.ParserTest do
  use ExUnit.Case, async: true

  alias Pinchflat.Downloading.OutputPath.Parser

  describe "parse/3" do
    test "it returns the rendered string when the string is valid" do
      assert {:ok, "bar"} = Parser.parse("{{ foo }}", %{"foo" => "bar"})
    end

    test "it works with filepath-like strings" do
      assert {:ok, "bar/baz"} =
               Parser.parse("{{ foo }}/{{ bar }}", %{"foo" => "bar", "bar" => "baz"})
    end

    test "it works when mixing text and variables" do
      assert {:ok, "bar text baz"} =
               Parser.parse("{{ foo }} text {{ bar }}", %{"foo" => "bar", "bar" => "baz"})
    end

    test "it removes the placeholder but doesn't blow up when the variable isn't provided" do
      assert {:ok, ""} = Parser.parse("{{ foo }}", %{})
    end

    test "it accepts any number of spaces between open and closing tags" do
      assert {:ok, "bar"} = Parser.parse("{{foo}}", %{"foo" => "bar"})
      assert {:ok, "bar"} = Parser.parse("{{ foo}}", %{"foo" => "bar"})
      assert {:ok, "bar"} = Parser.parse("{{foo }}", %{"foo" => "bar"})
      assert {:ok, "bar"} = Parser.parse("{{   foo   }}", %{"foo" => "bar"})
    end

    test "it doesn't interpret single braces as variables" do
      assert {:ok, "{foo}"} = Parser.parse("{foo}", %{})
    end

    test "it returns an error when the string is invalid" do
      assert {:error, "expected end of string"} = Parser.parse("{{ 1-1 }", %{})
    end

    test "it supports a custom fetcher function" do
      custom_fetcher = fn _, _ ->
        "quux"
      end

      assert {:ok, "quux"} = Parser.parse("{{ foo }}", %{}, custom_fetcher)
    end
  end
end
