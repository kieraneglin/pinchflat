defmodule Pinchflat.Sources.Source do
  @moduledoc """
  The Source schema.
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Pinchflat.Utils.ChangesetUtils

  alias Pinchflat.Tasks.Task
  alias Pinchflat.Media.MediaItem
  alias Pinchflat.Profiles.MediaProfile

  @allowed_fields ~w(
    collection_name
    collection_id
    collection_type
    custom_name
    index_frequency_minutes
    fast_index
    download_media
    last_indexed_at
    original_url
    download_cutoff_date
    media_profile_id
  )a

  @required_fields ~w(
    collection_name
    collection_id
    collection_type
    custom_name
    index_frequency_minutes
    fast_index
    download_media
    original_url
    media_profile_id
  )a

  schema "sources" do
    field :custom_name, :string
    field :collection_name, :string
    field :collection_id, :string
    field :collection_type, Ecto.Enum, values: [:channel, :playlist]
    field :index_frequency_minutes, :integer, default: 60 * 24
    field :fast_index, :boolean, default: false
    field :download_media, :boolean, default: true
    field :last_indexed_at, :utc_datetime
    # Only download media items that were published after this date
    field :download_cutoff_date, :date
    field :original_url, :string

    belongs_to :media_profile, MediaProfile

    has_many :tasks, Task
    has_many :media_items, MediaItem, foreign_key: :source_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(source, attrs) do
    source
    |> cast(attrs, @allowed_fields)
    |> dynamic_default(:custom_name, fn cs -> get_field(cs, :collection_name) end)
    |> validate_required(@required_fields)
    |> unique_constraint([:collection_id, :media_profile_id])
  end

  @doc false
  def index_frequency_when_fast_indexing do
    # 30 days in minutes
    60 * 24 * 30
  end

  @doc false
  def fast_index_frequency do
    # minutes
    15
  end
end
