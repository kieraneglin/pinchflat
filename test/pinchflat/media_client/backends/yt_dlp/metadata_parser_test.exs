defmodule Pinchflat.MediaClient.Backends.YtDlp.MediaParserTest do
  use ExUnit.Case, async: true

  alias Pinchflat.MediaClient.Backends.YtDlp.MetadataParser, as: Parser

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
    test "it extracts the video filepath", %{metadata: metadata} do
      result = Parser.parse_for_media_item(metadata)

      assert String.contains?(result.media_filepath, "bwRHIkYqYJo")
      assert String.ends_with?(result.media_filepath, ".mkv")
    end

    test "it extracts the title", %{metadata: metadata} do
      result = Parser.parse_for_media_item(metadata)

      assert result.title == "Trying to Wheelie Without the Rear Brake"
    end

    test "it returns the metadata as a map", %{metadata: metadata} do
      result = Parser.parse_for_media_item(metadata)

      assert result.metadata.client_response == metadata
    end
  end

  describe "parse_for_media_item/1 when testing subtitle metadata" do
    test "extracts the subtitle filepaths", %{metadata: metadata} do
      result = Parser.parse_for_media_item(metadata)

      assert [["de", german_filepath], ["en", english_filepath]] = result.subtitle_filepaths

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

    test "doesn't freak out if the video has no subtitles", %{metadata: metadata} do
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
end
