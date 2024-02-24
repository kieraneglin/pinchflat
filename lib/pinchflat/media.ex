defmodule Pinchflat.Media do
  @moduledoc """
  The Media context.
  """

  import Ecto.Query, warn: false

  alias Pinchflat.Repo
  alias Pinchflat.Tasks
  alias Pinchflat.Media.MediaItem
  alias Pinchflat.Sources.Source
  alias Pinchflat.Media.MediaMetadata

  @doc """
  Returns the list of media_items. Returns [%MediaItem{}, ...].
  """
  def list_media_items do
    Repo.all(MediaItem)
  end

  @doc """
  Returns a list of pending media_items for a given source, where
  pending means the `media_filepath` is `nil` AND the media_item
  matches the format selection rules of the parent media_profile.

  See `build_format_clauses` but tl;dr is it _may_ filter based
  on shorts or livestreams depending on the media_profile settings.

  Returns [%MediaItem{}, ...].
  """
  def list_pending_media_items_for(%Source{} = source) do
    media_profile = Repo.preload(source, :media_profile).media_profile

    MediaItem
    |> where([mi], mi.source_id == ^source.id and is_nil(mi.media_filepath))
    |> where(^build_format_clauses(media_profile))
    |> Repo.all()
  end

  @doc """
  Returns a list of downloaded media_items for a given source.

  Returns [%MediaItem{}, ...].
  """
  def list_downloaded_media_items_for(%Source{} = source) do
    MediaItem
    |> where([mi], mi.source_id == ^source.id and not is_nil(mi.media_filepath))
    |> Repo.all()
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

    from(mi in MediaItem,
      join: mi_search_index in assoc(mi, :media_items_search_index),
      where: fragment("media_items_search_index MATCH ?", ^search_term),
      select_merge: %{
        matching_search_term:
          fragment("""
            snippet(media_items_search_index, 0, '[PF_HIGHLIGHT]', '[/PF_HIGHLIGHT]', '...', 20) ||
            ' ' ||
            snippet(media_items_search_index, 1, '[PF_HIGHLIGHT]', '[/PF_HIGHLIGHT]', '...', 20)
          """)
      },
      order_by: [desc: fragment("rank")],
      limit: ^limit
    )
    |> Repo.all()
  end

  @doc """
  Gets a single media_item.

  Returns %MediaItem{}. Raises `Ecto.NoResultsError` if the Media item does not exist.
  """
  def get_media_item!(id), do: Repo.get!(MediaItem, id)

  @doc """
  Produces a flat list of the filesystem paths for a media_item's downloaded files

  Returns [binary()]
  """
  def media_filepaths(media_item) do
    mapped_struct = Map.from_struct(media_item)

    MediaItem.filepath_attributes()
    |> Enum.map(fn
      :subtitle_filepaths = field -> Enum.map(mapped_struct[field], fn [_, filepath] -> filepath end)
      field -> List.wrap(mapped_struct[field])
    end)
    |> List.flatten()
    |> Enum.filter(&is_binary/1)
  end

  @doc """
  Produces a flat list of the filesystem paths for a media_item's metadata files.
  Returns an empty list if the media_item has no metadata.

  Returns [binary()] | []
  """
  def metadata_filepaths(media_item) do
    metadata = Repo.preload(media_item, :metadata).metadata || %MediaMetadata{}
    mapped_struct = Map.from_struct(metadata)

    MediaMetadata.filepath_attributes()
    |> Enum.map(fn field -> mapped_struct[field] end)
    |> Enum.filter(&is_binary/1)
  end

  @doc """
  Creates a media_item. Returns {:ok, %MediaItem{}} | {:error, %Ecto.Changeset{}}.
  """
  def create_media_item(attrs) do
    %MediaItem{}
    |> MediaItem.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a media_item. Returns {:ok, %MediaItem{}} | {:error, %Ecto.Changeset{}}.
  """
  def update_media_item(%MediaItem{} = media_item, attrs) do
    media_item
    |> MediaItem.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a media_item and its associated tasks. Will leave files on disk.

  Returns {:ok, %MediaItem{}} | {:error, %Ecto.Changeset{}}.
  """
  def delete_media_item(%MediaItem{} = media_item) do
    Tasks.delete_tasks_for(media_item)
    Repo.delete(media_item)
  end

  @doc """
  Deletes the media_item's associated files. Will leave the media_item in the database.

  Returns {:ok, %MediaItem{}}
  """
  def delete_attachments(media_item) do
    media_item = Repo.preload(media_item, :metadata)

    media_item
    |> media_filepaths()
    |> Enum.concat(metadata_filepaths(media_item))
    |> Enum.each(&File.rm/1)

    # rmdir will attempt to delete the directory, but only if it is empty
    if media_item.media_filepath do
      File.rmdir(Path.dirname(media_item.media_filepath))
    end

    if media_item.metadata && media_item.metadata.metadata_filepath do
      File.rmdir(Path.dirname(media_item.metadata.metadata_filepath))
    end

    {:ok, media_item}
  end

  @doc """
  Deletes the media_item and all associated files. Attempts to delete the root directory
  but only if it is empty.

  Returns {:ok, %MediaItem{}}
  """
  def delete_media_item_and_attachments(media_item) do
    {:ok, _} = delete_attachments(media_item)

    delete_media_item(media_item)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking media_item changes.
  """
  def change_media_item(%MediaItem{} = media_item, attrs \\ %{}) do
    MediaItem.changeset(media_item, attrs)
  end

  defp build_format_clauses(media_profile) do
    mapped_struct = Map.from_struct(media_profile)

    Enum.reduce(mapped_struct, dynamic(true), fn attr, dynamic ->
      case {attr, media_profile} do
        {{:shorts_behaviour, :only}, %{livestream_behaviour: :only}} ->
          dynamic(
            [mi],
            ^dynamic and (mi.livestream == true or fragment("LOWER(?) LIKE LOWER(?)", mi.original_url, "%/shorts/%"))
          )

        # Technically redundant, but makes the other clauses easier to parse
        # (redundant because this condition is the same as the condition above, just flipped)
        {{:livestream_behaviour, :only}, %{shorts_behaviour: :only}} ->
          dynamic

        {{:shorts_behaviour, :only}, _} ->
          # return records with /shorts/ in the original_url
          dynamic([mi], ^dynamic and fragment("LOWER(?) LIKE LOWER(?)", mi.original_url, "%/shorts/%"))

        {{:livestream_behaviour, :only}, _} ->
          # return records with livestream: true
          dynamic([mi], ^dynamic and mi.livestream == true)

        {{:shorts_behaviour, :exclude}, %{livestream_behaviour: lb}} when lb != :only ->
          # return records without /shorts/ in the original_url
          dynamic([mi], ^dynamic and fragment("LOWER(?) NOT LIKE LOWER(?)", mi.original_url, "%/shorts/%"))

        {{:livestream_behaviour, :exclude}, %{shorts_behaviour: sb}} when sb != :only ->
          # return records with livestream: false
          dynamic([mi], ^dynamic and mi.livestream == false)

        _ ->
          dynamic
      end
    end)
  end
end
