defmodule Pinchflat.Downloading.QualityOptionBuilder do
  alias Pinchflat.Settings
  alias Pinchflat.Profiles.MediaProfile

  def build(%MediaProfile{preferred_resolution: :audio, media_container: container}) do
    acodec = Settings.get!(:audio_codec_preference)

    [:extract_audio, format_sort: "+acodec:#{acodec}", audio_format: container || "best"]
  end

  def build(%MediaProfile{preferred_resolution: resolution_atom, media_container: container}) do
    vcodec = Settings.get!(:video_codec_preference)
    acodec = Settings.get!(:audio_codec_preference)
    {resolution_string, _} = resolution_atom |> Atom.to_string() |> Integer.parse()

    [
      # Since Plex doesn't support reading metadata from MKV
      remux_video: container || "mp4",
      format_sort: "res:#{resolution_string},+codec:#{vcodec}:#{acodec}"
    ]
  end
end
