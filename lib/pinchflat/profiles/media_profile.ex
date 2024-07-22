defmodule Pinchflat.Profiles.MediaProfile do
  @moduledoc """
  A media profile is a set of configuration options that can be applied to many media sources
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias __MODULE__
  alias Pinchflat.Sources.Source

  @allowed_fields ~w(
    name
    output_path_template
    download_subs
    download_auto_subs
    embed_subs
    sub_langs
    download_thumbnail
    embed_thumbnail
    download_source_images
    download_metadata
    embed_metadata
    download_nfo
    sponsorblock_behaviour
    sponsorblock_categories
    shorts_behaviour
    livestream_behaviour
    preferred_resolution
    redownload_delay_days
    marked_for_deletion_at
  )a

  @required_fields ~w(name output_path_template)a

  schema "media_profiles" do
    field :name, :string
    field :redownload_delay_days, :integer

    field :output_path_template, :string,
      default: "/{{ source_custom_name }}/{{ upload_yyyy_mm_dd }} {{ title }}/{{ title }} [{{ id }}].{{ ext }}"

    field :download_subs, :boolean, default: false
    field :download_auto_subs, :boolean, default: false
    field :embed_subs, :boolean, default: false
    field :sub_langs, :string, default: "en"

    field :download_thumbnail, :boolean, default: false
    field :embed_thumbnail, :boolean, default: false
    field :download_source_images, :boolean, default: false

    field :download_metadata, :boolean, default: false
    field :embed_metadata, :boolean, default: false

    field :download_nfo, :boolean, default: false
    field :sponsorblock_behaviour, Ecto.Enum, values: [:disabled, :remove], default: :disabled
    field :sponsorblock_categories, {:array, :string}, default: []
    # NOTE: these do NOT speed up indexing - the indexer still has to go
    # through the entire collection to determine if a media is a short or
    # a livestream.
    # NOTE: these can BOTH be set to :only which will download shorts and
    # livestreams _only_ and ignore regular media. The redundant case
    # is when one is set to :only and the other is set to :exclude.
    # See `build_format_clauses` in the Media context for more.
    field :shorts_behaviour, Ecto.Enum, values: ~w(include exclude only)a, default: :include
    field :livestream_behaviour, Ecto.Enum, values: ~w(include exclude only)a, default: :include
    field :preferred_resolution, Ecto.Enum, values: ~w(4320p 2160p 1080p 720p 480p 360p audio)a, default: :"1080p"

    field :marked_for_deletion_at, :utc_datetime

    has_many :sources, Source

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(media_profile, attrs) do
    media_profile
    |> cast(attrs, @allowed_fields)
    |> validate_required(@required_fields)
    # Ensures it ends with `.{{ ext }}` or `.%(ext)s` or similar (with a little wiggle room)
    |> validate_format(:output_path_template, ext_regex(), message: "must end with .{{ ext }}")
    |> validate_number(:redownload_delay_days, greater_than_or_equal_to: 0)
    |> unique_constraint(:name)
  end

  @doc false
  def ext_regex do
    ~r/\.({{ ?ext ?}}|%\( ?ext ?\)[sS])$/
  end

  @doc false
  def json_exluded_fields do
    ~w(__meta__ __struct__ sources)a
  end

  defimpl Jason.Encoder, for: MediaProfile do
    def encode(value, opts) do
      value
      |> Map.drop(MediaProfile.json_exluded_fields())
      |> Jason.Encode.map(opts)
    end
  end
end
