defmodule Pinchflat.Media do
  @moduledoc """
  The Media context.
  """

  import Ecto.Query, warn: false

  alias Pinchflat.Repo
  alias Pinchflat.Tasks
  alias Pinchflat.Sources.Source
  alias Pinchflat.Media.MediaItem
  alias Pinchflat.Media.MediaQuery
  alias Pinchflat.Metadata.MediaMetadata
  alias Pinchflat.Filesystem.FilesystemHelpers

  @doc """
  Returns the list of media_items.

  Returns [%MediaItem{}, ...].
  """
  def list_media_items do
    Repo.all(MediaItem)
  end

  @doc """
  Returns a list of pending media_items for a given source, where
  pending means the `media_filepath` is `nil` AND the media_item
  matches the format selection rules of the parent media_profile.

  See `matching_download_criteria_for` but tl;dr is it _may_ filter based
  on shorts livestreams depending on the media_profile settings.

  Returns [%MediaItem{}, ...].
  """
  def list_pending_media_items_for(%Source{} = source, opts \\ []) do
    limit = Keyword.get(opts, :limit, nil)
    source = Repo.preload(source, :media_profile)

    MediaQuery.new()
    |> MediaQuery.for_source(source)
    |> matching_download_criteria_for(source)
    |> Repo.maybe_limit(limit)
    |> Repo.all()
  end

  @doc """
  Returns a list of downloaded media_items for a given source.

  Returns [%MediaItem{}, ...].
  """
  def list_downloaded_media_items_for(%Source{} = source, opts \\ []) do
    limit = Keyword.get(opts, :limit, nil)

    MediaQuery.new()
    |> MediaQuery.for_source(source)
    |> MediaQuery.with_media_filepath()
    |> Repo.maybe_limit(limit)
    |> Repo.all()
  end

  @doc """
  For a given media_item, tells you if it is pending download. This is defined as
  the media_item having a `media_filepath` of `nil` and matching the format selection
  rules of the parent media_profile.

  Intentionally does not take the `download_media` setting of the source into account.

  Returns boolean()
  """
  def pending_download?(%MediaItem{} = media_item) do
    media_item = Repo.preload(media_item, source: :media_profile)

    MediaQuery.new()
    |> MediaQuery.with_id(media_item.id)
    |> matching_download_criteria_for(media_item.source)
    |> Repo.exists?()
  end

  @doc """
  Returns a list of media_items that match the search term. Adds a `matching_search_term`
  virtual field to the result set.

  Has explit handling for blank search terms because SQLite doesn't like empty MATCH clauses.

  Returns [%MediaItem{}, ...].
  """
  def search(_search_term, _opts \\ [])
  def search("", _opts), do: []
  def search(nil, _opts), do: []

  def search(search_term, opts) do
    limit = Keyword.get(opts, :limit, 50)

    MediaQuery.new()
    |> MediaQuery.matching_search_term(search_term)
    |> Repo.maybe_limit(limit)
    |> Repo.all()
  end

  @doc """
  Gets a single media_item.

  Returns %MediaItem{}. Raises `Ecto.NoResultsError` if the Media item does not exist.
  """
  def get_media_item!(id), do: Repo.get!(MediaItem, id)

  @doc """
  Creates a media_item.

  Returns {:ok, %MediaItem{}} | {:error, %Ecto.Changeset{}}
  """
  def create_media_item(attrs) do
    %MediaItem{}
    |> MediaItem.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Creates a media item from the attributes returned by the video backend
  (read: yt-dlp).

  Unlike `create_media_item`, this will attempt an update if the media_item
  already exists. This is so that future indexing can pick up attributes that
  we may not have asked for in the past (eg: upload_date)

  Returns {:ok, %MediaItem{}} | {:error, %Ecto.Changeset{}}
  """
  def create_media_item_from_backend_attrs(source, media_attrs_struct) do
    attrs = Map.merge(%{source_id: source.id}, Map.from_struct(media_attrs_struct))

    %MediaItem{}
    |> MediaItem.changeset(attrs)
    |> Repo.insert(
      on_conflict: [
        set: Map.to_list(attrs)
      ],
      conflict_target: [:source_id, :media_id]
    )
  end

  @doc """
  Updates a media_item.

  Returns {:ok, %MediaItem{}} | {:error, %Ecto.Changeset{}}
  """
  def update_media_item(%MediaItem{} = media_item, attrs) do
    media_item
    |> MediaItem.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a media_item, its associated tasks, and our internal metadata files.
  Can optionally delete the media_item's media files (media, thumbnail, subtitles, etc).

  Returns {:ok, %MediaItem{}} | {:error, %Ecto.Changeset{}}
  """
  def delete_media_item(%MediaItem{} = media_item, opts \\ []) do
    delete_files = Keyword.get(opts, :delete_files, false)

    Tasks.delete_tasks_for(media_item)

    if delete_files do
      {:ok, _} = do_delete_media_files(media_item)
    end

    # Should delete these no matter what
    delete_internal_metadata_files(media_item)
    Repo.delete(media_item)
  end

  @doc """
  Deletes the tasks and media files associated with a media_item but leaves the
  media_item in the database. Does not delete anything to do with associated metadata.

  ## Options:
    - `:prevent_download` - If `true`, the media_item will be marked to prevent being redownloaded

  Returns {:ok, %MediaItem{}} | {:error, %Ecto.Changeset{}}
  """
  def delete_media_files(%MediaItem{} = media_item, opts \\ []) do
    prevent_download = Keyword.get(opts, :prevent_download, false)
    filepath_attrs = MediaItem.filepath_attribute_defaults()
    opt_attrs = %{prevent_download: prevent_download}

    Tasks.delete_tasks_for(media_item)
    {:ok, _} = do_delete_media_files(media_item)

    update_media_item(media_item, Map.merge(filepath_attrs, opt_attrs))
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking media_item changes.
  """
  def change_media_item(%MediaItem{} = media_item, attrs \\ %{}) do
    MediaItem.changeset(media_item, attrs)
  end

  defp do_delete_media_files(media_item) do
    mapped_struct = Map.from_struct(media_item)

    MediaItem.filepath_attributes()
    |> Enum.map(fn
      :subtitle_filepaths = field -> Enum.map(mapped_struct[field], fn [_, filepath] -> filepath end)
      field -> List.wrap(mapped_struct[field])
    end)
    |> List.flatten()
    |> Enum.filter(&is_binary/1)
    |> Enum.each(&FilesystemHelpers.delete_file_and_remove_empty_directories/1)

    {:ok, media_item}
  end

  defp delete_internal_metadata_files(media_item) do
    metadata = Repo.preload(media_item, :metadata).metadata || %MediaMetadata{}
    mapped_struct = Map.from_struct(metadata)

    MediaMetadata.filepath_attributes()
    |> Enum.map(fn field -> mapped_struct[field] end)
    |> Enum.filter(&is_binary/1)
    |> Enum.each(&FilesystemHelpers.delete_file_and_remove_empty_directories/1)
  end

  defp matching_download_criteria_for(query, source_with_preloads) do
    query
    |> MediaQuery.with_no_prevented_download()
    |> MediaQuery.with_no_media_filepath()
    |> MediaQuery.with_upload_date_after(source_with_preloads.download_cutoff_date)
    |> MediaQuery.with_format_preference(source_with_preloads.media_profile)
    |> MediaQuery.matching_title_regex(source_with_preloads.title_filter_regex)
  end
end
