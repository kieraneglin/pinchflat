defmodule Pinchflat.ProfilesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Pinchflat.Profiles` context.
  """

  @doc """
  Generate a media_profile.
  """
  def media_profile_fixture(attrs \\ %{}) do
    {:ok, media_profile} =
      attrs
      |> Enum.into(%{
        name: "Media Profile ##{:rand.uniform(1_000_000)}",
        output_path_template: "{{title}}.{{ext}}"
      })
      |> Pinchflat.Profiles.create_media_profile()

    media_profile
  end
end
