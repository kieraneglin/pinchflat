defmodule Pinchflat.Media do
  @moduledoc """
  The Media context.
  """

  import Ecto.Query, warn: false

  alias Pinchflat.Repo
  alias Pinchflat.Tasks
  alias Pinchflat.Media.MediaItem
  alias Pinchflat.MediaSource.Source

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

  Returns [%MediaItem{}, ...].
  """
  def search(search_term, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)

    from(mi in MediaItem,
      where: fragment("searchable @@ websearch_to_tsquery(?)", ^search_term),
      select_merge: %{
        matching_search_term:
          fragment(
            """
            ts_headline(
              'english',
              CONCAT(title, ' ', description),
              websearch_to_tsquery(?),
              'StartSel=[PF_HIGHLIGHT],StopSel=[/PF_HIGHLIGHT]'
            )
            """,
            ^search_term
          )
      },
      order_by: {
        :desc,
        fragment("ts_rank_cd(searchable, websearch_to_tsquery(?), 0)", ^search_term)
      },
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
    media_item
    |> media_filepaths()
    |> Enum.each(&File.rm/1)

    # Fails if the directory is not empty
    case File.rmdir(Path.dirname(media_item.media_filepath)) do
      :ok -> {:ok, media_item}
      {:error, :eexist} -> {:ok, media_item}
    end
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
          dynamic([mi], ^dynamic and (mi.livestream == true or fragment("? ILIKE ?", mi.original_url, "%/shorts/%")))

        # Technically redundant, but makes the other clauses easier to parse
        # (redundant because this condition is the same as the condition above, just flipped)
        {{:livestream_behaviour, :only}, %{shorts_behaviour: :only}} ->
          dynamic

        {{:shorts_behaviour, :only}, _} ->
          # return records with /shorts/ in the original_url
          dynamic([mi], ^dynamic and fragment("? ILIKE ?", mi.original_url, "%/shorts/%"))

        {{:livestream_behaviour, :only}, _} ->
          # return records with livestream: true
          dynamic([mi], ^dynamic and mi.livestream == true)

        {{:shorts_behaviour, :exclude}, %{livestream_behaviour: lb}} when lb != :only ->
          # return records without /shorts/ in the original_url
          dynamic([mi], ^dynamic and fragment("? NOT ILIKE ?", mi.original_url, "%/shorts/%"))

        {{:livestream_behaviour, :exclude}, %{shorts_behaviour: sb}} when sb != :only ->
          # return records with livestream: false
          dynamic([mi], ^dynamic and mi.livestream == false)

        _ ->
          dynamic
      end
    end)
  end
end
