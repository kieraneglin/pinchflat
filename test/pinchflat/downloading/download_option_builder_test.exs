defmodule Pinchflat.Downloading.DownloadOptionBuilderTest do
  use Pinchflat.DataCase
  import Pinchflat.MediaFixtures
  import Pinchflat.SourcesFixtures
  import Pinchflat.ProfilesFixtures

  alias Pinchflat.Sources
  alias Pinchflat.Profiles
  alias Pinchflat.Utils.FilesystemUtils
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

    test "respects custom media_item-related output path options", %{media_item: media_item} do
      media_item =
        update_media_profile_attribute(media_item, %{output_path_template: "{{ media_upload_date_index }}.%(ext)s"})

      assert {:ok, res} = DownloadOptionBuilder.build(media_item)

      assert {:output, "/tmp/test/media/99.%(ext)s"} in res
    end

    test "uses source's output override if present", %{media_item: media_item} do
      source = media_item.source
      {:ok, _} = Sources.update_source(source, %{output_path_template_override: "override.%(ext)s"})

      media_item =
        media_item
        |> Repo.reload()
        |> Repo.preload(source: :media_profile)

      assert {:ok, res} = DownloadOptionBuilder.build(media_item)

      assert {:output, "/tmp/test/media/override.%(ext)s"} in res
    end
  end

  describe "build/1 when testing default options" do
    test "it includes default options", %{media_item: media_item} do
      assert {:ok, res} = DownloadOptionBuilder.build(media_item)

      assert :no_progress in res
      assert :force_overwrites in res
      assert {:parse_metadata, "%(upload_date>%Y-%m-%d)s:(?P<meta_date>.+)"} in res
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

    test "appends -thumb to source's output path override, if present", %{media_item: media_item} do
      media_item = update_media_profile_attribute(media_item, %{download_thumbnail: true})
      {:ok, _} = Sources.update_source(media_item.source, %{output_path_template_override: "override.%(ext)s"})

      media_item =
        media_item
        |> Repo.reload()
        |> Repo.preload(source: :media_profile)

      assert {:ok, res} = DownloadOptionBuilder.build(media_item)

      assert {:output, "thumbnail:/tmp/test/media/override-thumb.%(ext)s"} in res
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
        assert {:remux_video, "mp4"} in res
      end)
    end

    test "it includes quality options for audio only", %{media_item: media_item} do
      media_item = update_media_profile_attribute(media_item, %{preferred_resolution: :audio})

      assert {:ok, res} = DownloadOptionBuilder.build(media_item)

      assert :extract_audio in res
      assert {:format, "bestaudio[ext=m4a]"} in res

      refute {:remux_video, "mp4"} in res
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

  describe "build/1 when testing config file options" do
    setup do
      base_dir = Path.join(Application.get_env(:pinchflat, :extras_directory), "yt-dlp-configs")

      {:ok, %{base_dir: base_dir}}
    end

    test "includes base config file if it's present", %{media_item: media_item, base_dir: base_dir} do
      filepath = Path.join(base_dir, "base-config.txt")

      FilesystemUtils.write_p!(filepath, "base config")

      assert {:ok, res} = DownloadOptionBuilder.build(media_item)
      assert {:config_locations, filepath} in res
    end

    test "includes media profile config file if it's present", %{media_item: media_item, base_dir: base_dir} do
      media_profile = media_item.source.media_profile
      filepath = Path.join(base_dir, "media-profile-#{media_profile.id}-config.txt")

      FilesystemUtils.write_p!(filepath, "profile config")

      assert {:ok, res} = DownloadOptionBuilder.build(media_item)
      assert {:config_locations, filepath} in res
    end

    test "includes source config file if it's present", %{media_item: media_item, base_dir: base_dir} do
      source = media_item.source
      filepath = Path.join(base_dir, "source-#{source.id}-config.txt")

      FilesystemUtils.write_p!(filepath, "profile config")

      assert {:ok, res} = DownloadOptionBuilder.build(media_item)
      assert {:config_locations, filepath} in res
    end

    test "includes media item config file if it's present", %{media_item: media_item, base_dir: base_dir} do
      filepath = Path.join(base_dir, "media-item-#{media_item.id}-config.txt")

      FilesystemUtils.write_p!(filepath, "media item config")

      assert {:ok, res} = DownloadOptionBuilder.build(media_item)
      assert {:config_locations, filepath} in res
    end

    test "does not include config file options if they are not present", %{media_item: media_item} do
      assert {:ok, res} = DownloadOptionBuilder.build(media_item)

      refute :config_locations in res
    end

    test "does not return a config file if it's blank", %{media_item: media_item, base_dir: base_dir} do
      filepath = Path.join(base_dir, "base-config.txt")

      FilesystemUtils.write_p!(filepath, " \n \n ")

      assert {:ok, res} = DownloadOptionBuilder.build(media_item)
      refute :config_locations in res
    end

    test "returns config files in order of precedence", %{media_item: media_item, base_dir: base_dir} do
      source = media_item.source
      media_profile = source.media_profile

      base_filepath = Path.join(base_dir, "base-config.txt")
      source_filepath = Path.join(base_dir, "source-#{source.id}-config.txt")
      media_item_filepath = Path.join(base_dir, "media-item-#{media_item.id}-config.txt")
      media_profile_filepath = Path.join(base_dir, "media-profile-#{media_profile.id}-config.txt")

      FilesystemUtils.write_p!(base_filepath, "config")
      FilesystemUtils.write_p!(source_filepath, "config")
      FilesystemUtils.write_p!(media_item_filepath, "config")
      FilesystemUtils.write_p!(media_profile_filepath, "config")

      assert {:ok, res} = DownloadOptionBuilder.build(media_item)

      expected_order = [
        {:config_locations, base_filepath},
        {:config_locations, media_profile_filepath},
        {:config_locations, source_filepath},
        {:config_locations, media_item_filepath}
      ]

      assert Enum.filter(res, fn
               {:config_locations, _} -> true
               _ -> false
             end) == expected_order
    end
  end

  describe "build_output_path_for/1" do
    test "builds an output path for a media item", %{media_item: media_item} do
      path = DownloadOptionBuilder.build_output_path_for(media_item)

      assert path == "/tmp/test/media/%(title)S.%(ext)s"
    end

    test "builds an output path for a source", %{media_item: media_item} do
      path = DownloadOptionBuilder.build_output_path_for(media_item.source)

      assert path == "/tmp/test/media/%(title)S.%(ext)s"
    end

    test "uses source's output override if present", %{media_item: media_item} do
      source = media_item.source
      {:ok, source} = Sources.update_source(source, %{output_path_template_override: "override.%(ext)s"})

      path = DownloadOptionBuilder.build_output_path_for(source)

      assert path == "/tmp/test/media/override.%(ext)s"
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
