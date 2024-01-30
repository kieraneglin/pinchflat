defmodule Pinchflat.Media.MediaItem do
  @moduledoc """
  The MediaItem schema.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Pinchflat.MediaSource.Channel
  alias Pinchflat.Media.MediaMetadata

  @required_fields ~w(media_id channel_id)a
  @allowed_fields ~w(title media_id video_filepath channel_id)a

  schema "media_items" do
    field :title, :string
    field :media_id, :string
    field :video_filepath, :string

    belongs_to :channel, Channel

    has_one :metadata, MediaMetadata, on_replace: :update

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(media_item, attrs) do
    media_item
    |> cast(attrs, @allowed_fields)
    |> cast_assoc(:metadata, with: &MediaMetadata.changeset/2, required: false)
    |> validate_required(@required_fields)
    |> unique_constraint([:media_id, :channel_id])
  end
end
