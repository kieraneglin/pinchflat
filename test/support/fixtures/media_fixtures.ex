defmodule Pinchflat.MediaFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Pinchflat.Media` context.
  """

  alias Pinchflat.SourcesFixtures
  alias Pinchflat.Filesystem.FilesystemHelpers

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
        short_form_content: false,
        media_filepath: "/video/#{Faker.File.file_name(:video)}",
        source_id: SourcesFixtures.source_fixture().id,
        upload_date: DateTime.utc_now()
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

  def media_item_with_metadata_attachments(attrs \\ %{}) do
    metadata_dir =
      Path.join(Application.get_env(:pinchflat, :metadata_directory), "#{:rand.uniform(1_000_000)}")

    json_gz_filepath = Path.join(metadata_dir, "metadata.json.gz")
    thumbnail_filepath = Path.join(metadata_dir, "thumbnail.jpg")

    FilesystemHelpers.cp_p!(media_metadata_filepath_fixture(), json_gz_filepath)
    FilesystemHelpers.cp_p!(thumbnail_filepath_fixture(), thumbnail_filepath)

    merged_attrs =
      Map.merge(attrs, %{
        metadata: %{
          metadata_filepath: json_gz_filepath,
          thumbnail_filepath: thumbnail_filepath
        }
      })

    media_item_with_attachments(merged_attrs)
  end

  def media_item_with_attachments(attrs \\ %{}) do
    stored_media_filepath =
      Path.join([
        Application.get_env(:pinchflat, :media_directory),
        "#{:rand.uniform(1_000_000)}",
        "#{:rand.uniform(1_000_000)}_media.mp4"
      ])

    FilesystemHelpers.cp_p!(media_filepath_fixture(), stored_media_filepath)

    merged_attrs = Map.merge(attrs, %{media_filepath: stored_media_filepath})
    media_item_fixture(merged_attrs)
  end

  def media_attributes_return_fixture do
    media_attributes = %{
      id: "video1",
      title: "Video 1",
      webpage_url: "https://example.com/video1",
      was_live: false,
      description: "desc1",
      aspect_ratio: 1.67,
      duration: 123.45,
      upload_date: "20210101"
    }

    Phoenix.json_library().encode!(media_attributes)
  end

  def media_filepath_fixture do
    Path.join([
      File.cwd!(),
      "test",
      "support",
      "files",
      "media.mkv"
    ])
  end

  def thumbnail_filepath_fixture do
    Path.join([
      File.cwd!(),
      "test",
      "support",
      "files",
      "thumbnail.jpg"
    ])
  end

  def infojson_filepath_fixture do
    Path.join([
      File.cwd!(),
      "test",
      "support",
      "files",
      "example.info.json"
    ])
  end

  def media_metadata_filepath_fixture do
    Path.join([
      File.cwd!(),
      "test",
      "support",
      "files",
      "media_metadata.json"
    ])
  end
end
