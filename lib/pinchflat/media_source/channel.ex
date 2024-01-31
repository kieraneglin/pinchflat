defmodule Pinchflat.MediaSource.Channel do
  @moduledoc """
  The Channel schema.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Pinchflat.Media.MediaItem
  alias Pinchflat.Profiles.MediaProfile

  @allowed_fields ~w(name channel_id index_frequency_minutes original_url media_profile_id)a
  @required_fields @allowed_fields -- ~w(index_frequency_minutes)a

  schema "channels" do
    field :name, :string
    field :channel_id, :string
    field :index_frequency_minutes, :integer
    # This should only be used for user reference going forward
    # as the channel_id should be used for all API calls
    field :original_url, :string

    belongs_to :media_profile, MediaProfile

    has_many :media_items, MediaItem

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(channel, attrs) do
    channel
    |> cast(attrs, @allowed_fields)
    |> validate_required(@required_fields)
    |> unique_constraint([:channel_id, :media_profile_id])
  end
end
