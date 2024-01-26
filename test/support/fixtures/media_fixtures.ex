defmodule Pinchflat.MediaFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Pinchflat.Media` context.
  """

  alias Pinchflat.MediaSourceFixtures

  @doc """
  Generate a media_item.
  """
  def media_item_fixture(attrs \\ %{}) do
    {:ok, media_item} =
      attrs
      |> Enum.into(%{
        media_id: Faker.String.base64(12),
        title: Faker.Commerce.product_name(),
        video_filepath: "/video/#{Faker.File.file_name(:video)}",
        channel_id: MediaSourceFixtures.channel_fixture().id
      })
      |> Pinchflat.Media.create_media_item()

    media_item
  end
end
