defmodule Pinchflat.MediaSource.Channel do
  @moduledoc """
  The Channel schema.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Pinchflat.Profiles.MediaProfile

  @required_fields ~w(name channel_id original_url media_profile_id)a
  @allowed_fields @required_fields

  schema "channels" do
    field :name, :string
    field :channel_id, :string
    # This should only be used for user reference going forward
    # as the channel_id should be used for all API calls
    field :original_url, :string

    belongs_to :media_profile, MediaProfile

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
