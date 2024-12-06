defmodule PinchflatWeb.Pages.PageHTML do
  use PinchflatWeb, :html

  alias Pinchflat.Utils.NumberUtils

  embed_templates "page_html/*"

  attr :media_filesize, :integer, required: true

  def readable_media_filesize(assigns) do
    {num, suffix} = NumberUtils.human_byte_size(assigns.media_filesize, precision: 2)

    assigns =
      Map.merge(assigns, %{
        num: num,
        suffix: suffix
      })

    ~H"""
    <.localized_number number={@num} /> {@suffix}
    """
  end
end
