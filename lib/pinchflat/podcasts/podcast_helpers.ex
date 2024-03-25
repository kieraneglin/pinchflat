defmodule Pinchflat.Podcasts.PostcastHelpers do
  alias Pinchflat.Repo
  alias Pinchflat.Media

  # TODO: test
  def persisted_media_items_for(source, opts \\ []) do
    limit = Keyword.get(opts, :limit, 500)

    source
    |> Media.list_downloaded_media_items_for(limit: limit)
    |> Enum.filter(fn media_item -> File.exists?(media_item.media_filepath) end)
  end

  # TODO: test
  # Returns string or nil
  def select_cover_image(source) do
    source_with_preloads = Repo.preload(source, :metadata)
    # Since we're looking for the metadata image, _any_ downloaded media
    # items should be fine
    media_items = Media.list_downloaded_media_items_for(source, limit: 1)

    source_with_preloads
    |> get_images_by_preference(media_items)
    |> Enum.reject(&is_nil(&1))
    |> Enum.find(&File.exists?/1)
  end

  def get_images_by_preference(source_with_preloads, []) do
    source_metadata = source_with_preloads.metadata

    [
      source_metadata.poster_filepath,
      source_metadata.banner_filepath
    ]
  end

  def get_images_by_preference(source_with_preloads, [media_item | _]) do
    media_item_with_preloads = Repo.preload(media_item, :metadata)
    media_item_metadata = media_item_with_preloads.metadata
    source_images = get_images_by_preference(source_with_preloads, [])

    source_images ++ [media_item_metadata.thumbnail_filepath]
  end
end
