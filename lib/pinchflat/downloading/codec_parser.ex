defmodule Pinchflat.Downloading.CodecParser do
  # TODO: test
  def generate_vcodec_string(nil), do: "bestvideo[vcodec~='^avc']/bestvideo"
  def generate_vcodec_string([]), do: generate_vcodec_string(nil)

  def generate_vcodec_string(video_codecs) do
    video_codecs
    |> Enum.map(&video_codec_map()[&1])
    |> Enum.reject(&is_nil/1)
    |> Enum.map(&"bestvideo[vcodec~='^#{&1}']")
    |> Enum.concat(["bestvideo", "best"])
    |> Enum.join("/")
  end

  # TODO: test
  def generate_acodec_string(nil), do: "bestaudio[acodec~='^mp4a']/bestaudio[acodec~='^mp3']/bestaudio"
  def generate_acodec_string([]), do: generate_acodec_string(nil)

  def generate_acodec_string(audio_codecs) do
    audio_codecs
    |> Enum.map(&audio_codec_map()[&1])
    |> Enum.reject(&is_nil/1)
    |> Enum.map(&"bestaudio[acodec~='^#{&1}']")
    |> Enum.concat(["bestaudio", "best"])
    |> Enum.join("/")
  end

  defp video_codec_map do
    %{
      "av01" => "av01",
      "avc" => "avc",
      "vp9" => "vp0?9"
    }
  end

  defp audio_codec_map do
    %{
      "flac" => "flac",
      "alac" => "alac",
      "wav" => "wav",
      "aiff" => "aiff",
      "aac" => "aac",
      "mp4a" => "mp4a",
      "mp3" => "mp3",
      "opus" => "opus",
      "vorbis" => "vorbis"
    }
  end
end
