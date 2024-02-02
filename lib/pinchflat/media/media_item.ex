defmodule Pinchflat.Media.MediaItem do
  @moduledoc """
  The MediaItem schema.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Pinchflat.Tasks.Task
  alias Pinchflat.MediaSource.Channel
  alias Pinchflat.Media.MediaMetadata

  @required_fields ~w(media_id source_id)a
  @allowed_fields ~w(title media_id media_filepath source_id subtitle_filepaths)a

  schema "media_items" do
    field :title, :string
    field :media_id, :string
    field :media_filepath, :string
    # This is an array of [iso-2 language, filepath] pairs. Probably could
    # be an associated record, but I don't see the benefit right now.
    # Will very likely revisit because I can't leave well-enough alone.
    field :subtitle_filepaths, {:array, {:array, :string}}, default: []

    belongs_to :channel, Channel, foreign_key: :source_id

    has_one :metadata, MediaMetadata, on_replace: :update

    has_many :tasks, Task

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(media_item, attrs) do
    media_item
    |> cast(attrs, @allowed_fields)
    |> cast_assoc(:metadata, with: &MediaMetadata.changeset/2, required: false)
    |> validate_required(@required_fields)
    |> unique_constraint([:media_id, :source_id])
  end
end
