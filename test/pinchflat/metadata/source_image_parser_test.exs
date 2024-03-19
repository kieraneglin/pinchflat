defmodule Pinchflat.Metadata.SourceImageParserTest do
  use Pinchflat.DataCase

  alias Pinchflat.Metadata.SourceImageParser

  @base_dir Application.compile_env(:pinchflat, :tmpfile_directory)

  describe "store_source_images/2" do
    test "returns a map of image types and locations" do
      metadata = render_parsed_metadata(:channel_source_metadata)

      expected = %{
        banner_filepath: "#{@base_dir}/banner.jpg",
        fanart_filepath: "#{@base_dir}/fanart.jpg",
        poster_filepath: "#{@base_dir}/poster.jpg"
      }

      assert SourceImageParser.store_source_images(@base_dir, metadata) == expected
    end

    test "returns the avatar_uncropped as the poster" do
      metadata = %{
        "thumbnails" => [
          %{"id" => "avatar_uncropped", "filepath" => "/app/test/support/files/channel_photos/a.0.jpg"}
        ]
      }

      expected = %{
        poster_filepath: "#{@base_dir}/poster.jpg"
      }

      assert SourceImageParser.store_source_images(@base_dir, metadata) == expected
    end

    test "returns the banner_uncropped as the fanart" do
      metadata = %{
        "thumbnails" => [
          %{"id" => "banner_uncropped", "filepath" => "/app/test/support/files/channel_photos/a.0.jpg"}
        ]
      }

      expected = %{
        fanart_filepath: "#{@base_dir}/fanart.jpg"
      }

      assert SourceImageParser.store_source_images(@base_dir, metadata) == expected
    end

    test "doesn't return a banner if no suitable images are found" do
      metadata = %{
        "thumbnails" => [
          %{
            "id" => "1",
            "filepath" => "foo.jpg",
            "width" => 100,
            "height" => 100
          }
        ]
      }

      expected = %{}

      assert SourceImageParser.store_source_images(@base_dir, metadata) == expected
    end

    test "doesn't blow up if empty metadata is passed" do
      metadata = %{}

      assert SourceImageParser.store_source_images(@base_dir, metadata) == %{}
    end

    test "doesn't blow up if no thumbnails are passed" do
      metadata = %{"thumbnails" => []}

      assert SourceImageParser.store_source_images(@base_dir, metadata) == %{}
    end
  end
end
