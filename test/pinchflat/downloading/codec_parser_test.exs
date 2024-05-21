defmodule Pinchflat.Downloading.CodecParserTest do
  use Pinchflat.DataCase

  alias Pinchflat.Settings
  alias Pinchflat.Downloading.CodecParser

  describe "generate_vcodec_string_from_settings/1" do
    test "returns a default vcodec string when setting isn't set" do
      Settings.set(video_codec_preference: [])

      assert "bestvideo[vcodec~='^avc']/bestvideo" == CodecParser.generate_vcodec_string_from_settings()
    end

    test "generates a vcodec string" do
      Settings.set(video_codec_preference: ["av01"])

      assert "bestvideo[vcodec~='^av01']/bestvideo" == CodecParser.generate_vcodec_string_from_settings()
    end
  end

  describe "generate_acodec_string_from_settings/1" do
    test "returns a default acodec string when setting isn't set" do
      Settings.set(audio_codec_preference: [])

      assert "bestaudio[acodec~='^mp4a']/bestaudio" == CodecParser.generate_acodec_string_from_settings()
    end

    test "generates an acodec string" do
      Settings.set(audio_codec_preference: ["mp3"])

      assert "bestaudio[acodec~='^mp3']/bestaudio" == CodecParser.generate_acodec_string_from_settings()
    end
  end

  describe "generate_vcodec_string/1" do
    test "returns a default vcodec string when nil" do
      assert "bestvideo[vcodec~='^avc']/bestvideo" == CodecParser.generate_vcodec_string(nil)
    end

    test "returns a default vcodec string when empty" do
      assert "bestvideo[vcodec~='^avc']/bestvideo" == CodecParser.generate_vcodec_string([])
    end

    test "generates a vcodec string" do
      assert "bestvideo[vcodec~='^av01']/bestvideo" == CodecParser.generate_vcodec_string(["av01"])
    end

    test "ignores options that don't exist" do
      assert "bestvideo[vcodec~='^av01']/bestvideo" == CodecParser.generate_vcodec_string(["av01", "foo"])
    end
  end

  describe "generate_acodec_string/1" do
    test "returns a default acodec string when nil" do
      assert "bestaudio[acodec~='^mp4a']/bestaudio" == CodecParser.generate_acodec_string(nil)
    end

    test "returns a default acodec string when empty" do
      assert "bestaudio[acodec~='^mp4a']/bestaudio" == CodecParser.generate_acodec_string([])
    end

    test "generates an acodec string" do
      assert "bestaudio[acodec~='^mp3']/bestaudio" == CodecParser.generate_acodec_string(["mp3"])
    end

    test "ignores options that don't exist" do
      assert "bestaudio[acodec~='^mp3']/bestaudio" == CodecParser.generate_acodec_string(["mp3", "foo"])
    end
  end
end
