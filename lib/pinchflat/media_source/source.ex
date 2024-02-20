defmodule Pinchflat.Sources.Source do
  @moduledoc """
  The Source schema.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Pinchflat.Media.MediaItem
  alias Pinchflat.Profiles.MediaProfile

  @allowed_fields ~w(
    collection_name
    collection_id
    collection_type
    friendly_name
    index_frequency_minutes
    download_media
    last_indexed_at
    original_url
    media_profile_id
  )a

  @required_fields ~w(
    collection_name
    collection_id
    collection_type
    download_media
    original_url
    media_profile_id
  )a

  schema "sources" do
    field :friendly_name, :string
    field :collection_name, :string
    field :collection_id, :string
    field :collection_type, Ecto.Enum, values: [:channel, :playlist]
    field :index_frequency_minutes, :integer, default: 60 * 24
    field :download_media, :boolean, default: true
    field :last_indexed_at, :utc_datetime
    # This should only be used for user reference going forward
    # as the collection_id should be used for all API calls
    field :original_url, :string

    belongs_to :media_profile, MediaProfile

    has_many :media_items, MediaItem, foreign_key: :source_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(source, attrs) do
    source
    |> cast(attrs, @allowed_fields)
    |> validate_required(@required_fields)
    |> unique_constraint([:collection_id, :media_profile_id])
  end
end
