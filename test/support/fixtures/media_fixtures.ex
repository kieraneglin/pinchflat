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
        media_filepath: "/video/#{Faker.File.file_name(:video)}",
        source_id: MediaSourceFixtures.source_fixture().id
      })
      |> Pinchflat.Media.create_media_item()

    media_item
  end

  @doc """
  Generate a media_item with metadata.
  """
  def media_item_with_metadata(attrs \\ %{}) do
    json_filepath =
      Path.join([
        Path.dirname(__ENV__.file),
        "support",
        "fixtures",
        "files",
        "media_metadata.json"
      ])

    {:ok, file_body} = File.read(json_filepath)
    {:ok, parsed_json} = Phoenix.json_library().decode(file_body)
    merged_attrs = Map.merge(attrs, %{metadata: %{client_respinse: parsed_json}})

    media_item_fixture(merged_attrs)
  end
end
