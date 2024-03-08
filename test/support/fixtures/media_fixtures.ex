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
    merged_attrs =
      Map.merge(attrs, %{
        metadata: %{
          metadata_filepath: Application.get_env(:pinchflat, :metadata_directory) <> "/metadata.json.gz",
          thumbnail_filepath: Application.get_env(:pinchflat, :metadata_directory) <> "/thumbnail.jpg"
        }
      })

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

  def media_attributes_return_fixture do
    media_attributes = %{
      id: "video1",
      title: "Video 1",
      original_url: "https://example.com/video1",
      was_live: false,
      description: "desc1"
    }

    Phoenix.json_library().encode!(media_attributes)
  end
end
