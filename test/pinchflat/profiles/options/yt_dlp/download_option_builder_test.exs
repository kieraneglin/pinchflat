defmodule Pinchflat.Profiles.Options.YtDlp.DownloadOptionBuilderTest do
  use Pinchflat.DataCase
  import Pinchflat.MediaFixtures
  import Pinchflat.ProfilesFixtures
  import Pinchflat.SourcesFixtures

  alias Pinchflat.Profiles
  alias Pinchflat.Profiles.Options.YtDlp.DownloadOptionBuilder

  setup do
    media_profile = media_profile_fixture(%{output_path_template: "{{ title }}.%(ext)s"})
    source = source_fixture(%{media_profile_id: media_profile.id, friendly_name: "my source"})
    media_item = Repo.preload(media_item_fixture(source_id: source.id), source: :media_profile)

    {:ok, media_item: media_item}
  end

  describe "build/1 when testing output options" do
    test "it generates an expanded output path based on the given template", %{media_item: media_item} do
      assert {:ok, res} = DownloadOptionBuilder.build(media_item)

      assert {:output, "/tmp/test/videos/%(title)S.%(ext)s"} in res
    end

    test "it respects custom output path options", %{media_item: media_item} do
      media_item =
        update_media_profile_attribute(media_item, %{output_path_template: "{{ source_friendly_name }}.%(ext)s"})

      assert {:ok, res} = DownloadOptionBuilder.build(media_item)

      assert {:output, "/tmp/test/videos/#{media_item.source.friendly_name}.%(ext)s"} in res
    end
  end

  describe "build/1 when testing default options" do
    test "it includes default options", %{media_item: media_item} do
      assert {:ok, res} = DownloadOptionBuilder.build(media_item)

      assert :no_progress in res
      assert :windows_filenames in res
    end
  end

  describe "build/1 when testing subtitle options" do
    test "includes :write_subs option when specified", %{media_item: media_item} do
      media_item = update_media_profile_attribute(media_item, %{download_subs: true})

      assert {:ok, res} = DownloadOptionBuilder.build(media_item)

      assert :write_subs in res
    end

    test "forces SRT format when download_subs is true", %{media_item: media_item} do
      media_item = update_media_profile_attribute(media_item, %{download_subs: true})

      assert {:ok, res} = DownloadOptionBuilder.build(media_item)

      assert {:convert_subs, "srt"} in res
    end

    test "includes :write_auto_subs option when specified", %{media_item: media_item} do
      media_item = update_media_profile_attribute(media_item, %{download_subs: true, download_auto_subs: true})

      assert {:ok, res} = DownloadOptionBuilder.build(media_item)

      assert :write_auto_subs in res
    end

    test "doesn't include :write_auto_subs option when download_subs is false", %{media_item: media_item} do
      media_item = update_media_profile_attribute(media_item, %{download_subs: false, download_auto_subs: true})

      assert {:ok, res} = DownloadOptionBuilder.build(media_item)

      refute :write_auto_subs in res
    end

    test "includes :embed_subs option when specified", %{media_item: media_item} do
      media_item = update_media_profile_attribute(media_item, %{embed_subs: true})

      assert {:ok, res} = DownloadOptionBuilder.build(media_item)

      assert :embed_subs in res
    end

    test "includes sub_langs option when download_subs is true", %{media_item: media_item} do
      media_item = update_media_profile_attribute(media_item, %{download_subs: true, sub_langs: "en"})

      assert {:ok, res} = DownloadOptionBuilder.build(media_item)

      assert {:sub_langs, "en"} in res
    end

    test "includes sub_langs option when embed_subs is true", %{media_item: media_item} do
      media_item = update_media_profile_attribute(media_item, %{embed_subs: true, sub_langs: "en"})

      assert {:ok, res} = DownloadOptionBuilder.build(media_item)

      assert {:sub_langs, "en"} in res
    end

    test "doesn't include sub_langs option when neither downloading nor embedding", %{media_item: media_item} do
      media_item =
        update_media_profile_attribute(media_item, %{embed_subs: false, download_subs: false, sub_langs: "en"})

      assert {:ok, res} = DownloadOptionBuilder.build(media_item)

      refute {:sub_langs, "en"} in res
    end
  end

  describe "build/1 when testing thumbnail options" do
    test "includes :write_thumbnail option when specified", %{media_item: media_item} do
      media_item = update_media_profile_attribute(media_item, %{download_thumbnail: true})

      assert {:ok, res} = DownloadOptionBuilder.build(media_item)

      assert :write_thumbnail in res
    end

    test "includes :embed_thumbnail option when specified", %{media_item: media_item} do
      media_item = update_media_profile_attribute(media_item, %{embed_thumbnail: true})

      assert {:ok, res} = DownloadOptionBuilder.build(media_item)

      assert :embed_thumbnail in res
    end

    test "doesn't include these options when not specified", %{media_item: media_item} do
      media_item = update_media_profile_attribute(media_item, %{embed_thumbnail: false, download_thumbnail: false})

      assert {:ok, res} = DownloadOptionBuilder.build(media_item)

      refute :write_thumbnail in res
      refute :embed_thumbnail in res
    end
  end

  describe "build/1 when testing metadata options" do
    test "includes :write_info_json option when specified", %{media_item: media_item} do
      media_item = update_media_profile_attribute(media_item, %{download_metadata: true})

      assert {:ok, res} = DownloadOptionBuilder.build(media_item)

      assert :write_info_json in res
      assert :clean_info_json in res
    end

    test "includes :embed_metadata option when specified", %{media_item: media_item} do
      media_item = update_media_profile_attribute(media_item, %{embed_metadata: true})

      assert {:ok, res} = DownloadOptionBuilder.build(media_item)

      assert :embed_metadata in res
    end

    test "doesn't include these options when not specified", %{media_item: media_item} do
      media_item = update_media_profile_attribute(media_item, %{embed_metadata: false, download_metadata: false})

      assert {:ok, res} = DownloadOptionBuilder.build(media_item)

      refute :write_info_json in res
      refute :clean_info_json in res
      refute :embed_metadata in res
    end
  end

  describe "build/1 when testing quality options" do
    test "it includes quality options", %{media_item: media_item} do
      media_item = update_media_profile_attribute(media_item, %{preferred_resolution: :"1080p"})

      assert {:ok, res} = DownloadOptionBuilder.build(media_item)

      assert {:format_sort, "res:1080,+codec:avc:m4a"} in res
    end
  end

  defp update_media_profile_attribute(media_item_with_preloads, attrs) do
    media_item_with_preloads.source.media_profile
    |> Profiles.change_media_profile(attrs)
    |> Repo.update!()

    media_item_with_preloads
    |> Repo.reload()
    |> Repo.preload(source: :media_profile)
  end
end
