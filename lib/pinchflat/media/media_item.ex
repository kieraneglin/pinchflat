defmodule Pinchflat.Media.MediaItem do
  use Ecto.Schema
  import Ecto.Changeset

  alias Pinchflat.MediaSource.Channel

  @required_fields ~w(media_id channel_id)a
  @allowed_fields ~w(title media_id video_filepath channel_id)a

  # TODO: consider making an attached `metadata` model to store the JSON response from whatever backend is used
  # TODO: make a tasks model to track the jobs spawned

  schema "media_items" do
    field :title, :string
    field :media_id, :string
    field :video_filepath, :string

    belongs_to :channel, Channel

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(media_item, attrs) do
    media_item
    |> cast(attrs, @allowed_fields)
    |> validate_required(@required_fields)
    |> unique_constraint([:media_id, :channel_id])
  end
end
