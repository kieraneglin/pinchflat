defmodule Pinchflat.Downloading.OutputPathBuilderTest do
  use Pinchflat.DataCase

  alias Pinchflat.Downloading.OutputPathBuilder

  describe "build/2" do
    test "it expands 'standard' curly brace variables in the template" do
      assert {:ok, res} = OutputPathBuilder.build("/videos/{{ title }}.{{ ext }}")

      assert res == "/videos/%(title)S.%(ext)S"
    end

    test "it expands 'custom' curly brace variables in the template" do
      assert {:ok, res} = OutputPathBuilder.build("/videos/{{ upload_year }}.{{ ext }}")

      assert res == "/videos/%(upload_date>%Y)S.%(ext)S"
    end

    test "it respects additional options" do
      assert {:ok, res} = OutputPathBuilder.build("/videos/{{ custom }}.{{ ext }}", %{"custom" => "test"})

      assert res == "/videos/test.%(ext)S"
    end

    test "it leaves yt-dlp variables alone" do
      assert {:ok, res} = OutputPathBuilder.build("/videos/%(title)s.%(ext)s")

      assert res == "/videos/%(title)s.%(ext)s"
    end

    test "recursively expands variables" do
      additional_options = %{
        "media_upload_date_index" => "99"
      }

      assert {:ok, res} = OutputPathBuilder.build("{{ season_episode_index_from_date }}.{{ ext }}", additional_options)

      assert res == "s%(upload_date>%Y)Se%(upload_date>%m%d)S99.%(ext)S"
    end
  end
end
