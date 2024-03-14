defmodule Pinchflat.Metadata.SourceMetadata do
  @moduledoc """
  The SourceMetadata schema.

  Look. Don't @ me about Metadata vs. Metadatum. I'm very sensitive.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Pinchflat.Sources.Source

  @allowed_fields ~w(metadata_filepath)a
  @required_fields ~w(metadata_filepath)a

  schema "source_metadata" do
    field :metadata_filepath, :string

    belongs_to :source, Source

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(source_metadata, attrs) do
    source_metadata
    |> cast(attrs, @allowed_fields)
    |> validate_required(@required_fields)
    |> unique_constraint([:source_id])
  end

  @doc false
  def filepath_attributes do
    ~w(metadata_filepath)a
  end
end
