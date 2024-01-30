defmodule Pinchflat.Media.MediaMetadata do
  @moduledoc """
  The MediaMetadata schema.

  Look. Don't @ me about Metadata vs. Metadatum. I'm very sensitive.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Pinchflat.Media.MediaItem

  schema "media_metadata" do
    field :client_response, :map

    belongs_to :media_item, MediaItem

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(media_metadata, attrs) do
    media_metadata
    |> cast(attrs, [:client_response])
    |> validate_required([:client_response])
    |> unique_constraint([:media_item_id])
  end
end
