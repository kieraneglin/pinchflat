defmodule Pinchflat.Media.MediaItem do
  @moduledoc """
  The MediaItem schema.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Pinchflat.Tasks.Task
  alias Pinchflat.Sources.Source
  alias Pinchflat.Media.MediaMetadata
  alias Pinchflat.Media.MediaItemSearchIndex

  @allowed_fields [
    # these fields are captured on indexing (and again on download)
    :title,
    :media_id,
    :description,
    :original_url,
    :livestream,
    :source_id,
    :short_form_content,
    :uploaded_at,
    # these fields are captured only on download
    :media_downloaded_at,
    :media_filepath,
    :media_size_bytes,
    :subtitle_filepaths,
    :thumbnail_filepath,
    :metadata_filepath
  ]
  # Pretty much all the fields captured at index are required.
  @required_fields ~w(
    title
    original_url
    livestream
    media_id
    source_id
    uploaded_at
    short_form_content
    )a

  schema "media_items" do
    field :title, :string
    field :media_id, :string
    field :description, :string
    field :original_url, :string
    field :livestream, :boolean, default: false
    field :short_form_content, :boolean, default: false
    field :media_downloaded_at, :utc_datetime
    field :uploaded_at, :utc_datetime

    field :media_filepath, :string
    field :media_size_bytes, :integer
    field :thumbnail_filepath, :string
    field :metadata_filepath, :string
    # This is an array of [iso-2 language, filepath] pairs. Probably could
    # be an associated record, but I don't see the benefit right now.
    # Will very likely revisit because I can't leave well-enough alone.
    field :subtitle_filepaths, {:array, {:array, :string}}, default: []

    field :matching_search_term, :string, virtual: true

    belongs_to :source, Source

    has_one :metadata, MediaMetadata, on_replace: :update
    has_one :media_items_search_index, MediaItemSearchIndex, foreign_key: :id

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

  @doc false
  def filepath_attributes do
    ~w(media_filepath thumbnail_filepath metadata_filepath subtitle_filepaths)a
  end
end
