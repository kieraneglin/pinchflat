defmodule Pinchflat.MediaSourceFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Pinchflat.MediaSource` context.
  """

  alias Pinchflat.Repo
  alias Pinchflat.ProfilesFixtures
  alias Pinchflat.MediaSource.Channel

  @doc """
  Generate a channel.
  """
  def channel_fixture(attrs \\ %{}) do
    {:ok, channel} =
      %Channel{}
      |> Channel.changeset(
        Enum.into(attrs, %{
          name: "Channel ##{:rand.uniform(1_000_000)}",
          channel_id: Base.encode16(:crypto.hash(:md5, "#{:rand.uniform(1_000_000)}")),
          original_url: "https://www.youtube.com/channel/#{:rand.uniform(1_000_000)}",
          media_profile_id: ProfilesFixtures.media_profile_fixture().id
        })
      )
      |> Repo.insert()

    channel
  end
end
