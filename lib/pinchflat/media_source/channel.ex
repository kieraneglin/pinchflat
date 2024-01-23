defmodule Pinchflat.MediaSource.Channel do
  @moduledoc """
  The Channel schema.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Pinchflat.Profiles.MediaProfile

  schema "channels" do
    field :name, :string
    field :channel_id, :string

    belongs_to :media_profile, MediaProfile

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(channel, attrs) do
    channel
    |> cast(attrs, [:name, :channel_id, :media_profile_id])
    |> validate_required([:name, :channel_id, :media_profile_id])
    |> unique_constraint([:channel_id, :media_profile_id])
  end
end
