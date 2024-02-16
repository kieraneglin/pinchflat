defmodule Pinchflat.Media.MediaItemSearchIndex do
  @moduledoc """
  The MediaItem fts5 search index. Not made to be directly interacted with,
  but I figured it'd be better to have it in-app so it's not a mystery.
  """

  use Ecto.Schema

  @primary_key {:id, :id, autogenerate: true, source: :rowid}
  schema "media_items_search_index" do
    field :title, :string
    field :description, :string

    field :rank, :float, virtual: true
  end
end
