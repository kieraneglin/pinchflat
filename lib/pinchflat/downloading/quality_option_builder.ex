defmodule Pinchflat.Downloading.QualityOptionBuilder do
  alias Pinchflat.Settings
  alias Pinchflat.Profiles.MediaProfile

  # TODO: test
  def build(%MediaProfile{preferred_resolution: :audio, media_container: container}) do
    acodec = Settings.get!(:audio_codec_preference)

    [
      :extract_audio,
      format_sort: "+acodec:#{acodec}",
      audio_format: container || "best"
    ] ++ build_format_string(nil)
  end

  def build(%MediaProfile{preferred_resolution: resolution_atom, media_container: container}) do
    vcodec = Settings.get!(:video_codec_preference)
    acodec = Settings.get!(:audio_codec_preference)
    {resolution_string, _} = resolution_atom |> Atom.to_string() |> Integer.parse()

    [
      # Since Plex doesn't support reading metadata from MKV
      remux_video: container || "mp4",
      format_sort: "res:#{resolution_string},+codec:#{vcodec}:#{acodec}"
    ] ++ build_format_string(nil)
  end

  # TODO: pass in the entire media profile once we have the language preference column
  # TODO: test
  defp build_format_string(language_preference) do
    if language_preference do
      "bestvideo*+bestaudio[#{build_format_modifier(language_preference)}]/bestvideo*+bestaudio/best"
    else
      "bestvideo*+bestaudio/best"
    end
  end

  # TODO: test
  defp build_format_modifier("original"), do: "format_note*=original"
  defp build_format_modifier("default"), do: "format_note*=(default)"
  # This uses the carat to anchor the language to the beginning of the string
  # since that's what's needed to match `en` to `en-US` and `en-GB`, etc. The user
  # can always specify the full language code if they want.
  defp build_format_modifier(language_code), do: "language^=#{language_code}"
end
