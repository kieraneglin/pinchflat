defmodule Pinchflat.MediaClient.Backends.YtDlp.MetadataParser do
  def parse_for_media_item(metadata) do
    %{
      video_filepath: metadata["filepath"]
    }
  end
end
