defmodule Pinchflat.MediaClient.Backends.YtDlp.OutputPathBuilderTest do
  use Pinchflat.DataCase

  alias Pinchflat.Profiles.Options.YtDlp.OutputPathBuilder

  describe "build/1" do
    test "it expands 'standard' curly brace variables in the template" do
      assert {:ok, res} = OutputPathBuilder.build("/videos/{{ title }}.{{ ext }}")

      assert res == "/videos/%(title)S.%(ext)S"
    end

    test "it expands 'custom' curly brace variables in the template" do
      assert {:ok, res} = OutputPathBuilder.build("/videos/{{ upload_year }}.{{ ext }}")

      assert res == "/videos/%(upload_date>%Y)S.%(ext)S"
    end

    test "it leaves yt-dlp variables alone" do
      assert {:ok, res} = OutputPathBuilder.build("/videos/%(title)s.%(ext)s")

      assert res == "/videos/%(title)s.%(ext)s"
    end
  end
end
