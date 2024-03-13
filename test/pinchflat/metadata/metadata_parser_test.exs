defmodule Pinchflat.Metadata.MetadataParserTest do
  use Pinchflat.DataCase

  alias Pinchflat.Metadata.MetadataParser, as: Parser

  setup do
    json_filepath =
      Path.join([
        File.cwd!(),
        "test",
        "support",
        "files",
        "media_metadata.json"
      ])

    {:ok, file_body} = File.read(json_filepath)
    {:ok, parsed_json} = Phoenix.json_library().decode(file_body)

    {:ok,
     %{
       metadata: parsed_json
     }}
  end

  describe "parse_for_media_item/1 when testing media metadata" do
    test "it extracts the media filepath", %{metadata: metadata} do
      result = Parser.parse_for_media_item(metadata)

      assert String.contains?(result.media_filepath, "bwRHIkYqYJo")
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
    test "extracts the thumbnail filepath", %{metadata: metadata} do
      result = Parser.parse_for_media_item(metadata)

      assert String.ends_with?(result.thumbnail_filepath, ".webp")
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
    test "extracts the metadata filepath", %{metadata: metadata} do
      result = Parser.parse_for_media_item(metadata)

      assert String.ends_with?(result.metadata_filepath, ".info.json")
    end

    test "doesn't freak out if the media has no infojson", %{metadata: metadata} do
      metadata = Map.put(metadata, "infojson_filename", nil)

      result = Parser.parse_for_media_item(metadata)

      assert result.metadata_filepath == nil
    end
  end
end
