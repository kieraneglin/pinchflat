defmodule PinchflatWeb.Pages.PageHTML do
  use PinchflatWeb, :html

  alias Pinchflat.Utils.NumberUtils

  embed_templates "page_html/*"

  def readable_media_filesize(media_filesize) do
    {num, suffix} = NumberUtils.human_byte_size(media_filesize, precision: 1)

    "#{Float.round(num)} #{suffix}"
  end
end
