defmodule Pinchflat.Podcasts.PodcastHelpers do
  @moduledoc """
  Methods for fetching postcast-related data from a source
  or its media items
  """

  use Pinchflat.Media.MediaQuery

  alias Pinchflat.Repo
  alias Pinchflat.Metadata.MediaMetadata
  alias Pinchflat.Metadata.SourceMetadata

  @doc """
  Returns a list of media items that have been downloaded to disk
  and have been proven to still exist there.

  Useful for podcasts since we don't want to serve media that
  has been deleted or moved, but it's also fairly generally useful
  so I could see this being moved in the future.

  Options:
    - limit: integer - the maximum number of media items to return

  Returns: [%MediaItem{}]
  """
  def persisted_media_items_for(source, opts \\ []) do
    limit = Keyword.get(opts, :limit, 1_000)

    MediaQuery.new()
    |> where(^dynamic(^MediaQuery.for_source(source) and ^MediaQuery.downloaded()))
    |> order_by(desc: :uploaded_at)
    |> Repo.maybe_limit(limit)
    |> Repo.all()
    |> Enum.filter(fn media_item -> File.exists?(media_item.media_filepath) end)
  end

  @doc """
  Selects a cover image for a source based on the source's metadata
  and the metadata of the media items associated with the source. Also
  ensures images exist on disk.

  Only one media item should need to be returned since this is using the
  internal metadata which, so long as the media_item was _downloaded_, should
  be guaranteed to exist.

  Prefers the source's poster, then fanart, then the media item's thumbnail.

  Returns: {:ok, filepath} | {:error, :no_suitable_image}
  """
  def select_cover_image(source, media_items) do
    source_with_preloads = Repo.preload(source, :metadata)

    source_with_preloads
    |> get_images_by_preference(media_items)
    |> Enum.reject(&is_nil(&1))
    |> Enum.find(&File.exists?/1)
    |> case do
      nil -> {:error, :no_suitable_image}
      filepath -> {:ok, filepath}
    end
  end

  defp get_images_by_preference(source_with_preloads, []) do
    source_metadata = source_with_preloads.metadata || %SourceMetadata{}

    [
      source_metadata.poster_filepath,
      source_metadata.fanart_filepath
    ]
  end

  defp get_images_by_preference(source_with_preloads, [media_item | _]) do
    media_item_with_preloads = Repo.preload(media_item, :metadata)
    media_item_metadata = media_item_with_preloads.metadata || %MediaMetadata{}
    source_images = get_images_by_preference(source_with_preloads, [])

    source_images ++ [media_item_metadata.thumbnail_filepath]
  end
end
