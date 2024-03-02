defmodule PinchflatWeb.Sources.SourceHTML do
  use PinchflatWeb, :html

  embed_templates "source_html/*"

  @doc """
  Renders a source form.
  """
  attr :changeset, Ecto.Changeset, required: true
  attr :action, :string, required: true
  attr :media_profiles, :list, required: true

  def source_form(assigns)

  def friendly_index_frequencies do
    [
      {"On Create", -1},
      {"1 Hour", 60},
      {"3 Hours", 3 * 60},
      {"6 Hours", 6 * 60},
      {"12 Hours", 12 * 60},
      {"Daily (recommended)", 24 * 60},
      {"Weekly", 7 * 24 * 60},
      {"Monthly", 30 * 24 * 60}
    ]
  end
end
