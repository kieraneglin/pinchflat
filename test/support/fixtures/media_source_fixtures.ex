defmodule Pinchflat.MediaSourceFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Pinchflat.MediaSource` context.
  """

  alias Pinchflat.Repo
  alias Pinchflat.ProfilesFixtures
  alias Pinchflat.MediaSource.Source

  @doc """
  Generate a source.
  """
  def source_fixture(attrs \\ %{}) do
    {:ok, source} =
      %Source{}
      |> Source.changeset(
        Enum.into(attrs, %{
          collection_name: "Source ##{:rand.uniform(1_000_000)}",
          collection_id: Base.encode16(:crypto.hash(:md5, "#{:rand.uniform(1_000_000)}")),
          collection_type: "channel",
          friendly_name: "Cool and good internal name!",
          original_url: "https://www.youtube.com/channel/#{Faker.String.base64(12)}",
          media_profile_id: ProfilesFixtures.media_profile_fixture().id,
          index_frequency_minutes: 60
        })
      )
      |> Repo.insert()

    source
  end
end
