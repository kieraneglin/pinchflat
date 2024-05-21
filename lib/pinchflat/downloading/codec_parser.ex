defmodule Pinchflat.Downloading.CodecParser do
  @moduledoc """
  Functions for generating yt-dlp codec strings
  """

  alias Pinchflat.Settings

  @doc """
  Generate a video codec string based on the value of the video_codec_preference setting.

  Returns binary()
  """
  def generate_vcodec_string_from_settings do
    generate_vcodec_string(Settings.get!(:video_codec_preference))
  end

  @doc """
  Generate an audio codec string based on the value of the audio_codec_preference setting.

  Returns binary()
  """
  def generate_acodec_string_from_settings do
    generate_acodec_string(Settings.get!(:audio_codec_preference))
  end

  @doc """
  Generate a video codec string from a list of video codecs.

  If the list is nil or empty, the default video codec is AVC.

  Returns binary()
  """
  def generate_vcodec_string(nil), do: "bestvideo[vcodec~='^avc']/bestvideo"
  def generate_vcodec_string([]), do: generate_vcodec_string(nil)

  def generate_vcodec_string(video_codecs) do
    video_codecs
    |> Enum.map(&video_codec_map()[&1])
    |> Enum.reject(&is_nil/1)
    |> Enum.map(&"bestvideo[vcodec~='^#{&1}']")
    |> Enum.concat(["bestvideo"])
    |> Enum.join("/")
  end

  @doc """
  Generate an audio codec string from a list of audio codecs.

  If the list is nil or empty, the default audio codec is MP4A.

  Returns binary()
  """
  def generate_acodec_string(nil), do: "bestaudio[acodec~='^mp4a']/bestaudio"
  def generate_acodec_string([]), do: generate_acodec_string(nil)

  def generate_acodec_string(audio_codecs) do
    audio_codecs
    |> Enum.map(&audio_codec_map()[&1])
    |> Enum.reject(&is_nil/1)
    |> Enum.map(&"bestaudio[acodec~='^#{&1}']")
    |> Enum.concat(["bestaudio"])
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
      "aac" => "aac",
      "mp4a" => "mp4a",
      "mp3" => "mp3",
      "opus" => "opus"
    }
  end
end
