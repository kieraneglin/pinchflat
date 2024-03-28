defmodule Pinchflat.Downloading.DownloadOptionBuilderTest do
  use Pinchflat.DataCase
  import Pinchflat.MediaFixtures
  import Pinchflat.SourcesFixtures
  import Pinchflat.ProfilesFixtures

  alias Pinchflat.Profiles
  alias Pinchflat.Downloading.DownloadOptionBuilder

  setup do
    media_profile = media_profile_fixture(%{output_path_template: "{{ title }}.%(ext)s"})
    source = source_fixture(%{media_profile_id: media_profile.id, custom_name: "my source"})
    media_item = Repo.preload(media_item_fixture(source_id: source.id), source: :media_profile)

    {:ok, media_item: media_item}
  end

  describe "build/1 when testing output options" do
    test "it generates an expanded output path based on the given template", %{media_item: media_item} do
      assert {:ok, res} = DownloadOptionBuilder.build(media_item)

      assert {:output, "/tmp/test/media/%(title)S.%(ext)s"} in res
    end

    test "it respects custom output path options", %{media_item: media_item} do
      media_item =
        update_media_profile_attribute(media_item, %{output_path_template: "{{ source_custom_name }}.%(ext)s"})

      assert {:ok, res} = DownloadOptionBuilder.build(media_item)

      assert {:output, "/tmp/test/media/#{media_item.source.custom_name}.%(ext)s"} in res
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

    test "doesn't include :embed_subs option when preferred_resolution is :audio", %{media_item: media_item} do
      media_item = update_media_profile_attribute(media_item, %{embed_subs: true, preferred_resolution: :audio})

      assert {:ok, res} = DownloadOptionBuilder.build(media_item)

      refute :embed_subs in res
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

    test "appends -thumb to the thumbnail name when download_thumbnail is true", %{media_item: media_item} do
      media_item = update_media_profile_attribute(media_item, %{download_thumbnail: true})

      assert {:ok, res} = DownloadOptionBuilder.build(media_item)

      assert {:output, "thumbnail:/tmp/test/media/%(title)S-thumb.%(ext)s"} in res
    end

    test "converts thumbnail to jpg when download_thumbnail is true", %{media_item: media_item} do
      media_item = update_media_profile_attribute(media_item, %{download_thumbnail: true})

      assert {:ok, res} = DownloadOptionBuilder.build(media_item)

      assert {:convert_thumbnail, "jpg"} in res
    end

    test "includes :embed_thumbnail option when specified", %{media_item: media_item} do
      media_item = update_media_profile_attribute(media_item, %{embed_thumbnail: true})

      assert {:ok, res} = DownloadOptionBuilder.build(media_item)

      assert :embed_thumbnail in res
    end

    test "convertes thumbnail to jpg when embed_thumbnail is true", %{media_item: media_item} do
      media_item = update_media_profile_attribute(media_item, %{embed_thumbnail: true})

      assert {:ok, res} = DownloadOptionBuilder.build(media_item)

      assert {:convert_thumbnail, "jpg"} in res
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
    test "it includes quality options" do
      resolutions = ["360", "480", "720", "1080", "2160"]

      Enum.each(resolutions, fn resolution ->
        resolution_atom = String.to_existing_atom(resolution <> "p")

        media_profile = media_profile_fixture(%{preferred_resolution: resolution_atom})
        source = source_fixture(%{media_profile_id: media_profile.id})
        media_item = Repo.preload(media_item_fixture(source_id: source.id), source: :media_profile)

        assert {:ok, res} = DownloadOptionBuilder.build(media_item)
        assert {:format_sort, "res:#{resolution},+codec:avc:m4a"} in res
      end)
    end

    test "it includes quality options for audio only", %{media_item: media_item} do
      media_item = update_media_profile_attribute(media_item, %{preferred_resolution: :audio})

      assert {:ok, res} = DownloadOptionBuilder.build(media_item)

      assert :extract_audio in res
      assert {:format, "bestaudio[ext=m4a]"} in res
    end
  end

  describe "build/1 when testing sponsorblock options" do
    test "includes :sponsorblock_remove option when specified", %{media_item: media_item} do
      media_item =
        update_media_profile_attribute(media_item, %{
          sponsorblock_behaviour: :remove,
          sponsorblock_categories: ["sponsor", "intro"]
        })

      assert {:ok, res} = DownloadOptionBuilder.build(media_item)

      assert {:sponsorblock_remove, "sponsor,intro"} in res
    end

    test "does not include :sponsorblock_remove option without categories", %{media_item: media_item} do
      media_item =
        update_media_profile_attribute(media_item, %{
          sponsorblock_behaviour: :remove,
          sponsorblock_categories: []
        })

      assert {:ok, res} = DownloadOptionBuilder.build(media_item)

      refute {:sponsorblock_remove, ""} in res
      refute {:sponsorblock_remove, []} in res
      refute :sponsorblock_remove in res
    end

    test "does not include any sponsorblock options when disabled", %{media_item: media_item} do
      media_item =
        update_media_profile_attribute(media_item, %{sponsorblock_behaviour: :disabled})

      assert {:ok, res} = DownloadOptionBuilder.build(media_item)

      refute {:sponsorblock_remove, ""} in res
      refute {:sponsorblock_remove, []} in res
      refute :sponsorblock_remove in res
    end
  end

  describe "build_output_path_for/1" do
    test "builds an output path for a source", %{media_item: media_item} do
      path = DownloadOptionBuilder.build_output_path_for(media_item.source)

      assert path == "/tmp/test/media/%(title)S.%(ext)s"
    end
  end

  defp update_media_profile_attribute(media_item_with_preloads, attrs) do
    media_item_with_preloads.source.media_profile
    |> Profiles.change_media_profile(attrs)
    |> Repo.update()

    media_item_with_preloads
    |> Repo.reload()
    |> Repo.preload([source: :media_profile], force: true)
  end
end
