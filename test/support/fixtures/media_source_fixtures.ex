defmodule Pinchflat.MediaSourceFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Pinchflat.MediaSource` context.
  """

  alias Pinchflat.ProfilesFixtures

  @doc """
  Generate a channel.
  """
  def channel_fixture(attrs \\ %{}) do
    {:ok, channel} =
      attrs
      |> Enum.into(%{
        channel_id: Base.encode16(:crypto.hash(:md5, "#{:rand.uniform(1_000_000)}"), case: :lower),
        name: "Channel ##{:rand.uniform(1_000_000)}",
        media_profile_id: ProfilesFixtures.media_profile_fixture().id
      })
      |> Pinchflat.MediaSource.create_channel()

    channel
  end
end
