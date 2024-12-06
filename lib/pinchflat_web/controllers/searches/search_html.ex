defmodule PinchflatWeb.Searches.SearchHTML do
  use PinchflatWeb, :html

  embed_templates "search_html/*"

  @doc """
  Highlight search terms in a string of text based on `[PF_HIGHLIGHT]` and `[/PF_HIGHLIGHT]` tags
  """
  attr :text, :string, required: true

  def highlight_search_terms(assigns) do
    split_string = String.split(assigns.text, ~r{\[PF_HIGHLIGHT\]|\[/PF_HIGHLIGHT\]}, include_captures: true)
    assigns = assign(assigns, split_string: split_string)

    ~H"""
    <%= for fragment <- @split_string do %>
      {render_fragment(fragment)}
    <% end %>
    """
  end

  defp render_fragment("[PF_HIGHLIGHT]"), do: raw(~s(<span class="font-bold italic">))
  defp render_fragment("[/PF_HIGHLIGHT]"), do: raw("</span>")
  defp render_fragment(text), do: text
end
