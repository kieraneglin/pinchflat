defmodule PinchflatWeb.MediaItems.MediaItemHTML do
  use PinchflatWeb, :html

  embed_templates "media_item_html/*"

  @doc """
  Renders a media item form.
  """
  attr :changeset, Ecto.Changeset, required: true
  attr :action, :string, required: true

  def media_item_form(assigns)

  def media_file_exists?(media_item) do
    !!media_item.media_filepath and File.exists?(media_item.media_filepath)
  end

  # TODO: update for new format types
  def media_type(media_item) do
    case Path.extname(media_item.media_filepath) do
      ext when ext in [".mp4", ".webm", ".mkv"] -> :video
      ext when ext in [".mp3", ".m4a"] -> :audio
      _ -> :unknown
    end
  end
end
