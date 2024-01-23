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
        name: "some name",
        output_path_template: "some output_path_template"
      })
      |> Pinchflat.Profiles.create_media_profile()

    media_profile
  end
end
