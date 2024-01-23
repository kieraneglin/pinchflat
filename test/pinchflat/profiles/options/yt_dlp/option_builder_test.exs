defmodule Pinchflat.Profiles.Options.YtDlp.OptionBuilderTest do
  use ExUnit.Case, async: true

  alias Pinchflat.Profiles.MediaProfile
  alias Pinchflat.Profiles.Options.YtDlp.OptionBuilder

  @media_profile %MediaProfile{
    output_path_template: "videos/{{ title }}.%(ext)s"
  }

  describe "build/1" do
    test "it generates an expanded output path based on the given template" do
      assert {:ok, res} = OptionBuilder.build(@media_profile)

      assert {:output, "/tmp/yt-dlp/videos/%(title)S.%(ext)s"} in res
    end
  end
end
