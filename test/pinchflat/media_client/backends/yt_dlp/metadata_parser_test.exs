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

  describe "parse_for_media_item/1" do
    test "it extracts the video filepath", %{metadata: metadata} do
      result = Parser.parse_for_media_item(metadata)

      assert String.contains?(result.video_filepath, "bwRHIkYqYJo")
      assert String.ends_with?(result.video_filepath, ".mkv")
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
end
