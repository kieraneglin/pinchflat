defmodule Pinchflat.Profiles.Options.YtDlp.DownloadOptionBuilderTest do
  use ExUnit.Case, async: true

  alias Pinchflat.Profiles.MediaProfile
  alias Pinchflat.Profiles.Options.YtDlp.DownloadOptionBuilder

  @media_profile %MediaProfile{
    output_path_template: "{{ title }}.%(ext)s"
  }

  describe "build/1" do
    test "it generates an expanded output path based on the given template" do
      assert {:ok, res} = DownloadOptionBuilder.build(@media_profile)

      assert {:output, "/tmp/videos/%(title)S.%(ext)s"} in res
    end
  end

  describe "build/1 when testing subtitle options" do
    test "includes :write_subs option when specified" do
      media_profile = %MediaProfile{@media_profile | download_subs: true}

      assert {:ok, res} = DownloadOptionBuilder.build(media_profile)

      assert :write_subs in res
    end

    test "forces SRT format when download_subs is true" do
      media_profile = %MediaProfile{@media_profile | download_subs: true}

      assert {:ok, res} = DownloadOptionBuilder.build(media_profile)

      assert {:convert_subs, "srt"} in res
    end

    test "includes :write_auto_subs option when specified" do
      media_profile = %MediaProfile{@media_profile | download_subs: true, download_auto_subs: true}

      assert {:ok, res} = DownloadOptionBuilder.build(media_profile)

      assert :write_auto_subs in res
    end

    test "doesn't include :write_auto_subs option when download_subs is false" do
      media_profile = %MediaProfile{@media_profile | download_subs: false, download_auto_subs: true}

      assert {:ok, res} = DownloadOptionBuilder.build(media_profile)

      refute :write_auto_subs in res
    end

    test "includes :embed_subs option when specified" do
      media_profile = %MediaProfile{@media_profile | embed_subs: true}

      assert {:ok, res} = DownloadOptionBuilder.build(media_profile)

      assert :embed_subs in res
    end

    test "includes sub_langs option when download_subs is true" do
      media_profile = %MediaProfile{@media_profile | download_subs: true, sub_langs: "en"}

      assert {:ok, res} = DownloadOptionBuilder.build(media_profile)

      assert {:sub_langs, "en"} in res
    end

    test "includes sub_langs option when embed_subs is true" do
      media_profile = %MediaProfile{@media_profile | embed_subs: true, sub_langs: "en"}

      assert {:ok, res} = DownloadOptionBuilder.build(media_profile)

      assert {:sub_langs, "en"} in res
    end

    test "doesn't include sub_langs option when neither downloading nor embedding" do
      media_profile = %MediaProfile{
        @media_profile
        | embed_subs: false,
          download_subs: false,
          sub_langs: "en"
      }

      assert {:ok, res} = DownloadOptionBuilder.build(media_profile)

      refute {:sub_langs, "en"} in res
    end

    test "other struct attributes are ignored" do
      media_profile = %MediaProfile{@media_profile | id: -1}

      assert {:ok, res} = DownloadOptionBuilder.build(media_profile)

      refute {:id, -1} in res
    end
  end

  describe "build/1 when testing thumbnail options" do
    test "includes :write_thumbnail option when specified" do
      media_profile = %MediaProfile{@media_profile | download_thumbnail: true}

      assert {:ok, res} = DownloadOptionBuilder.build(media_profile)

      assert :write_thumbnail in res
    end

    test "includes :embed_thumbnail option when specified" do
      media_profile = %MediaProfile{@media_profile | embed_thumbnail: true}

      assert {:ok, res} = DownloadOptionBuilder.build(media_profile)

      assert :embed_thumbnail in res
    end

    test "doesn't include these options when not specified" do
      media_profile = %MediaProfile{
        @media_profile
        | embed_thumbnail: false,
          download_thumbnail: false
      }

      assert {:ok, res} = DownloadOptionBuilder.build(media_profile)

      refute :write_thumbnail in res
      refute :embed_thumbnail in res
    end
  end

  describe "build/1 when testing metadata options" do
    test "includes :write_info_json option when specified" do
      media_profile = %MediaProfile{@media_profile | download_metadata: true}

      assert {:ok, res} = DownloadOptionBuilder.build(media_profile)

      assert :write_info_json in res
      assert :clean_info_json in res
    end

    test "includes :embed_metadata option when specified" do
      media_profile = %MediaProfile{@media_profile | embed_metadata: true}

      assert {:ok, res} = DownloadOptionBuilder.build(media_profile)

      assert :embed_metadata in res
    end

    test "doesn't include these options when not specified" do
      media_profile = %MediaProfile{
        @media_profile
        | embed_metadata: false,
          download_metadata: false
      }

      assert {:ok, res} = DownloadOptionBuilder.build(media_profile)

      refute :write_info_json in res
      refute :clean_info_json in res
      refute :embed_metadata in res
    end
  end
end
