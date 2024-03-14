defmodule Pinchflat.SourcesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Pinchflat.Sources` context.
  """

  alias Pinchflat.Repo
  alias Pinchflat.ProfilesFixtures
  alias Pinchflat.Sources.Source

  @doc """
  Generate a source.
  """
  def source_fixture(attrs \\ %{}) do
    {:ok, source} =
      %Source{}
      |> Source.changeset(
        Enum.into(
          attrs,
          %{
            collection_name: "Source ##{:rand.uniform(1_000_000)}",
            collection_id: Base.encode16(:crypto.hash(:md5, "#{:rand.uniform(1_000_000)}")),
            collection_type: "channel",
            custom_name: "Cool and good internal name!",
            original_url: "https://www.youtube.com/channel/#{Faker.String.base64(12)}",
            media_profile_id: ProfilesFixtures.media_profile_fixture().id,
            index_frequency_minutes: 60
          }
        ),
        :pre_insert
      )
      |> Repo.insert()

    source
  end

  @doc """
  Generate a source with metadata.
  """
  def source_with_metadata(attrs \\ %{}) do
    merged_attrs =
      Map.merge(attrs, %{
        metadata: %{
          metadata_filepath: Application.get_env(:pinchflat, :metadata_directory) <> "/metadata.json.gz"
        }
      })

    source_fixture(merged_attrs)
  end

  def source_attributes_return_fixture do
    source_attributes = [
      %{
        id: "video1",
        title: "Video 1",
        webpage_url: "https://example.com/video1",
        was_live: false,
        description: "desc1",
        aspect_ratio: 1.67,
        duration: 12.34,
        upload_date: "20210101"
      },
      %{
        id: "video2",
        title: "Video 2",
        webpage_url: "https://example.com/video2",
        was_live: true,
        description: "desc2",
        aspect_ratio: 1.67,
        duration: 345.67,
        upload_date: "20220202"
      },
      %{
        id: "video3",
        title: "Video 3",
        webpage_url: "https://example.com/video3",
        was_live: false,
        description: "desc3",
        aspect_ratio: 1.0,
        duration: 678.90,
        upload_date: "20230303"
      }
    ]

    source_attributes
    |> Enum.map_join("\n", &Phoenix.json_library().encode!(&1))
  end
end
