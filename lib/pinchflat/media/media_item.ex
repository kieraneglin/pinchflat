defmodule Pinchflat.Media.MediaItem do
  @moduledoc """
  The MediaItem schema.
  """

  use Ecto.Schema
  use Pinchflat.Media.MediaQuery

  import Ecto.Changeset
  import Pinchflat.Utils.ChangesetUtils

  alias __MODULE__
  alias Pinchflat.Repo
  alias Pinchflat.Sources
  alias Pinchflat.Tasks.Task
  alias Pinchflat.Sources.Source
  alias Pinchflat.Metadata.MediaMetadata
  alias Pinchflat.Media.MediaItemsSearchIndex

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
    :upload_date_index,
    :duration_seconds,
    # these fields are captured only on download
    :media_downloaded_at,
    :media_filepath,
    :media_size_bytes,
    :subtitle_filepaths,
    :thumbnail_filepath,
    :metadata_filepath,
    :nfo_filepath,
    # These are user or system controlled fields
    :prevent_download,
    :prevent_culling,
    :culled_at,
    :media_redownloaded_at
  ]
  # Pretty much all the fields captured at index are required.
  @required_fields ~w(
    uuid
    title
    original_url
    livestream
    media_id
    source_id
    uploaded_at
    short_form_content
  )a

  schema "media_items" do
    # This is _not_ used as the primary key or internally in the database
    # relations. This is only used to prevent an enumeration attack on the streaming
    # and RSS feed endpoints since those _must_ be public (ie: no basic auth)
    field :uuid, Ecto.UUID

    field :title, :string
    field :media_id, :string
    field :description, :string
    field :original_url, :string
    field :livestream, :boolean, default: false
    field :short_form_content, :boolean, default: false
    field :media_downloaded_at, :utc_datetime
    field :media_redownloaded_at, :utc_datetime
    field :uploaded_at, :utc_datetime
    field :upload_date_index, :integer, default: 0
    field :duration_seconds, :integer

    field :media_filepath, :string
    field :media_size_bytes, :integer
    field :thumbnail_filepath, :string
    field :metadata_filepath, :string
    field :nfo_filepath, :string
    # This is an array of [iso-2 language, filepath] pairs. Probably could
    # be an associated record, but I don't see the benefit right now.
    # Will very likely revisit because I can't leave well-enough alone.
    field :subtitle_filepaths, {:array, {:array, :string}}, default: []

    field :prevent_download, :boolean, default: false
    field :prevent_culling, :boolean, default: false
    field :culled_at, :utc_datetime

    field :matching_search_term, :string, virtual: true

    belongs_to :source, Source

    has_one :metadata, MediaMetadata, on_replace: :update
    has_one :media_items_search_index, MediaItemsSearchIndex, foreign_key: :id

    has_many :tasks, Task

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(media_item, attrs) do
    media_item
    |> cast(attrs, @allowed_fields)
    |> cast_assoc(:metadata, with: &MediaMetadata.changeset/2, required: false)
    |> dynamic_default(:uuid, fn _ -> Ecto.UUID.generate() end)
    |> update_upload_date_index()
    |> validate_required(@required_fields)
    |> unique_constraint([:media_id, :source_id])
  end

  @doc false
  def filepath_attributes do
    ~w(media_filepath thumbnail_filepath metadata_filepath subtitle_filepaths nfo_filepath)a
  end

  @doc false
  def filepath_attribute_defaults do
    filepath_attributes()
    |> Enum.map(fn
      :subtitle_filepaths -> {:subtitle_filepaths, []}
      field -> {field, nil}
    end)
    |> Enum.into(%{})
  end

  @doc false
  def json_exluded_fields do
    ~w(__meta__ __struct__ metadata tasks media_items_search_index)a
  end

  # Run it on new records no matter what. The method we delegate to
  # will handle the case where `uploaded_at` is `nil`
  defp update_upload_date_index(%{data: %{id: nil}} = changeset) do
    do_update_upload_date_index(changeset)
  end

  # For the update case, we only want to recalculate if the day itself has changed.
  # For instance, this is useful in the migration from `upload_date` to `uploaded_at`
  defp update_upload_date_index(%{changes: changes} = changeset) when is_map_key(changes, :uploaded_at) do
    old_uploaded_at = changeset.data.uploaded_at
    new_uploaded_at = get_change(changeset, :uploaded_at)
    upload_dates_match = DateTime.to_date(old_uploaded_at) == DateTime.to_date(new_uploaded_at)

    if upload_dates_match do
      changeset
    else
      do_update_upload_date_index(changeset)
    end
  end

  # If the record is persisted and the `uploaded_at` field is not being changed,
  # we don't need to recalculate the index.
  defp update_upload_date_index(changeset), do: changeset

  defp do_update_upload_date_index(%{changes: changes} = changeset) when is_map_key(changes, :uploaded_at) do
    source_id = get_field(changeset, :source_id)
    source = Sources.get_source!(source_id)
    # Channels should count down from 99, playlists should count up from 0
    # This reflects the fact that channels prepend new videos to the top of the list
    # and playlists append new videos to the bottom of the list.
    default_index = if source.collection_type == :channel, do: 99, else: 0
    aggregator = if source.collection_type == :channel, do: :min, else: :max
    change_direction = if source.collection_type == :channel, do: -1, else: 1

    current_max =
      MediaQuery.new()
      |> where(^dynamic([mi], ^MediaQuery.upload_date_matches(changes.uploaded_at) and ^MediaQuery.for_source(source)))
      |> Repo.aggregate(aggregator, :upload_date_index)

    case current_max do
      nil -> put_change(changeset, :upload_date_index, default_index)
      max -> put_change(changeset, :upload_date_index, max + change_direction)
    end
  end

  defp do_update_upload_date_index(changeset), do: changeset

  defimpl Jason.Encoder, for: MediaItem do
    def encode(value, opts) do
      value
      |> Repo.preload(:source)
      |> Map.drop(MediaItem.json_exluded_fields())
      |> Jason.Encode.map(opts)
    end
  end
end
