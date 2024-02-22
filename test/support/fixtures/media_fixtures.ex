defmodule Pinchflat.MediaFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Pinchflat.Media` context.
  """

  alias Pinchflat.SourcesFixtures

  @doc """
  Generate a media_item.
  """
  def media_item_fixture(attrs \\ %{}) do
    media_id = Faker.String.base64(12)

    {:ok, media_item} =
      attrs
      |> Enum.into(%{
        media_id: media_id,
        title: Faker.Commerce.product_name(),
        original_url: "https://www.youtube.com/watch?v=#{media_id}",
        livestream: false,
        media_filepath: "/video/#{Faker.File.file_name(:video)}",
        source_id: SourcesFixtures.source_fixture().id
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
        File.cwd!(),
        "test",
        "support",
        "files",
        "media_metadata.json"
      ])

    {:ok, file_body} = File.read(json_filepath)
    {:ok, parsed_json} = Phoenix.json_library().decode(file_body)
    merged_attrs = Map.merge(attrs, %{metadata: %{client_respinse: parsed_json}})

    media_item_fixture(merged_attrs)
  end

  def media_item_with_attachments(attrs \\ %{}) do
    stored_media_filepath =
      Path.join([
        Application.get_env(:pinchflat, :media_directory),
        "#{:rand.uniform(1_000_000)}",
        "#{:rand.uniform(1_000_000)}_media.mkv"
      ])

    fixture_media_filepath =
      Path.join([
        File.cwd!(),
        "test",
        "support",
        "files",
        "media.mkv"
      ])

    :ok = File.mkdir_p(Path.dirname(stored_media_filepath))
    :ok = File.cp(fixture_media_filepath, stored_media_filepath)

    merged_attrs = Map.merge(attrs, %{media_filepath: stored_media_filepath})
    media_item_fixture(merged_attrs)
  end
end
