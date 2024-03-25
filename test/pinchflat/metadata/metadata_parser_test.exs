defmodule Pinchflat.Metadata.MetadataParserTest do
  use Pinchflat.DataCase
  import Pinchflat.MediaFixtures

  alias Pinchflat.Metadata.MetadataParser, as: Parser

  setup do
    {:ok, %{metadata: render_parsed_metadata(:media_metadata)}}
  end

  describe "parse_for_media_item/1 when testing media metadata" do
    test "it extracts the media filepath", %{metadata: metadata} do
      result = Parser.parse_for_media_item(metadata)

      assert String.contains?(result.media_filepath, "Pinchflat Example Video-ABC123")
      assert String.ends_with?(result.media_filepath, ".mkv")
    end

    test "it extracts the title", %{metadata: metadata} do
      result = Parser.parse_for_media_item(metadata)

      assert result.title == metadata["title"]
    end

    test "it extracts the description", %{metadata: metadata} do
      result = Parser.parse_for_media_item(metadata)

      assert result.description == metadata["description"]
    end

    test "it extracts the original_url", %{metadata: metadata} do
      result = Parser.parse_for_media_item(metadata)

      assert result.original_url == metadata["original_url"]
    end

    test "it extracts the media_id", %{metadata: metadata} do
      result = Parser.parse_for_media_item(metadata)

      assert result.media_id == metadata["id"]
    end

    test "it extracts the livestream flag", %{metadata: metadata} do
      result = Parser.parse_for_media_item(metadata)

      assert result.livestream == metadata["was_live"]
    end
  end

  describe "parse_for_media_item/1 when testing subtitle metadata" do
    test "extracts the subtitle filepaths", %{metadata: metadata} do
      result = Parser.parse_for_media_item(metadata)

      assert [["de", german_filepath], ["en", english_filepath] | _rest] = result.subtitle_filepaths

      assert String.ends_with?(english_filepath, ".en.srt")
      assert String.ends_with?(german_filepath, ".de.srt")
    end

    test "sorts the subtitle filepaths by language", %{metadata: metadata} do
      metadata =
        Map.put(metadata, "requested_subtitles", %{
          "en" => %{"filepath" => "en.srt"},
          "za" => %{"filepath" => "za.srt"},
          "de" => %{"filepath" => "de.srt"},
          "al" => %{"filepath" => "al.srt"}
        })

      result = Parser.parse_for_media_item(metadata)

      assert [["al", _], ["de", _], ["en", _], ["za", _]] = result.subtitle_filepaths
    end

    test "doesn't freak out if the media has no subtitles", %{metadata: metadata} do
      metadata = Map.put(metadata, "requested_subtitles", %{})

      result = Parser.parse_for_media_item(metadata)

      assert result.subtitle_filepaths == []
    end

    test "doesn't freak out if the requested_subtitles key is missing", %{metadata: metadata} do
      metadata = Map.delete(metadata, "requested_subtitles")

      result = Parser.parse_for_media_item(metadata)

      assert result.subtitle_filepaths == []
    end
  end

  describe "parse_for_media_item/1 when testing thumbnail metadata" do
    setup %{metadata: metadata} do
      thumbnail_filepath =
        metadata["thumbnails"]
        |> Enum.reverse()
        |> Enum.find_value(fn attrs -> attrs["filepath"] end)
        |> String.split(~r{\.}, include_captures: true)
        |> List.insert_at(-3, "-thumb")
        |> Enum.join()

      :ok = File.cp(thumbnail_filepath_fixture(), thumbnail_filepath)

      on_exit(fn -> File.rm(thumbnail_filepath) end)

      {:ok, filepath: thumbnail_filepath}
    end

    test "extracts the thumbnail filepath", %{metadata: metadata} do
      result = Parser.parse_for_media_item(metadata)

      assert String.ends_with?(result.thumbnail_filepath, ".webp")
    end

    # NOTE: this can be removed once this bug is fixed
    # https://github.com/yt-dlp/yt-dlp/issues/9445
    # and the associated conditional in the parser is removed
    test "automatically appends `-thumb` to the thumbnail filename", %{metadata: metadata} do
      result = Parser.parse_for_media_item(metadata)

      assert String.contains?(result.thumbnail_filepath, "-thumb.webp")
    end

    test "doesn't include thumbnail if the file doesn't exist on-disk", %{metadata: metadata, filepath: filepath} do
      File.rm(filepath)

      result = Parser.parse_for_media_item(metadata)

      assert result.thumbnail_filepath == nil
    end

    test "doesn't freak out if the media has no thumbnails", %{metadata: metadata} do
      metadata = Map.put(metadata, "thumbnails", %{})

      result = Parser.parse_for_media_item(metadata)

      assert result.thumbnail_filepath == nil
    end

    test "doesn't freak out if the thumbnails key is missing", %{metadata: metadata} do
      metadata = Map.delete(metadata, "thumbnails")

      result = Parser.parse_for_media_item(metadata)

      assert result.thumbnail_filepath == nil
    end
  end

  describe "parse_for_media_item/1 when testing infojson metadata" do
    setup %{metadata: metadata} do
      infojson_filepath = metadata["infojson_filename"]
      :ok = File.cp(infojson_filepath_fixture(), infojson_filepath)

      on_exit(fn -> File.rm(infojson_filepath) end)

      {:ok, filepath: infojson_filepath}
    end

    test "extracts the metadata filepath", %{metadata: metadata} do
      result = Parser.parse_for_media_item(metadata)

      assert String.ends_with?(result.metadata_filepath, ".info.json")
    end

    test "doesn't include metadata if the file doesn't exist on-disk", %{metadata: metadata, filepath: filepath} do
      File.rm(filepath)

      result = Parser.parse_for_media_item(metadata)

      assert result.metadata_filepath == nil
    end

    test "doesn't freak out if the media has no infojson", %{metadata: metadata} do
      metadata = Map.put(metadata, "infojson_filename", nil)

      result = Parser.parse_for_media_item(metadata)

      assert result.metadata_filepath == nil
    end
  end
end
