defmodule Pinchflat.Metadata.MediaMetadata do
  @moduledoc """
  The MediaMetadata schema.

  Look. Don't @ me about Metadata vs. Metadatum. I'm very sensitive.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Pinchflat.Media.MediaItem

  @allowed_fields ~w(metadata_filepath thumbnail_filepath)a
  @required_fields ~w(metadata_filepath thumbnail_filepath)a

  schema "media_metadata" do
    field :metadata_filepath, :string
    field :thumbnail_filepath, :string

    belongs_to :media_item, MediaItem

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(media_metadata, attrs) do
    media_metadata
    |> cast(attrs, @allowed_fields)
    |> validate_required(@required_fields)
    |> unique_constraint([:media_item_id])
  end

  @doc false
  def filepath_attributes do
    ~w(metadata_filepath thumbnail_filepath)a
  end
end
