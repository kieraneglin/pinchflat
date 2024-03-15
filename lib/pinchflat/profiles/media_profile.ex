defmodule Pinchflat.Profiles.MediaProfile do
  @moduledoc """
  A media profile is a set of configuration options that can be applied to many media sources
  """

  use Ecto.Schema
  import Ecto.Changeset

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
    download_metadata
    embed_metadata
    download_nfo
    shorts_behaviour
    livestream_behaviour
    preferred_resolution
  )a

  @required_fields ~w(name output_path_template)a

  schema "media_profiles" do
    field :name, :string

    field :output_path_template, :string,
      default: "/{{ source_custom_name }}/{{ upload_yyyy_mm_dd }} {{ title }}/{{ title }} [{{ id }}].{{ ext }}"

    field :download_subs, :boolean, default: false
    field :download_auto_subs, :boolean, default: false
    field :embed_subs, :boolean, default: false
    field :sub_langs, :string, default: "en"

    field :download_thumbnail, :boolean, default: false
    field :embed_thumbnail, :boolean, default: false

    field :download_metadata, :boolean, default: false
    field :embed_metadata, :boolean, default: false

    field :download_nfo, :boolean, default: false
    # NOTE: these do NOT speed up indexing - the indexer still has to go
    # through the entire collection to determine if a media is a short or
    # a livestream.
    # NOTE: these can BOTH be set to :only which will download shorts and
    # livestreams _only_ and ignore regular media. The redundant case
    # is when one is set to :only and the other is set to :exclude.
    # See `build_format_clauses` in the Media context for more.
    field :shorts_behaviour, Ecto.Enum, values: ~w(include exclude only)a, default: :include
    field :livestream_behaviour, Ecto.Enum, values: ~w(include exclude only)a, default: :include

    field :preferred_resolution, Ecto.Enum, values: ~w(2160p 1080p 720p 480p 360p audio)a, default: :"1080p"

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
    |> unique_constraint(:name)
  end

  defp ext_regex do
    ~r/\.({{ ?ext ?}}|%\( ?ext ?\)[sS])$/
  end
end
