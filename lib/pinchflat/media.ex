defmodule Pinchflat.Media do
  @moduledoc """
  The Media context.
  """

  import Ecto.Query, warn: false

  alias Pinchflat.Repo
  alias Pinchflat.Tasks
  alias Pinchflat.Media.MediaItem
  alias Pinchflat.MediaSource.Channel

  @doc """
  Returns the list of media_items. Returns [%MediaItem{}, ...].
  """
  def list_media_items do
    Repo.all(MediaItem)
  end

  @doc """
  Returns a list of pending media_items for a given channel, where
  pending means the `video_filepath` is `nil`.

  Returns [%MediaItem{}, ...].
  """
  def list_pending_media_items_for(%Channel{} = channel) do
    from(
      m in MediaItem,
      where: m.channel_id == ^channel.id and is_nil(m.video_filepath)
    )
    |> Repo.all()
  end

  @doc """
  Gets a single media_item.

  Returns %MediaItem{}. Raises `Ecto.NoResultsError` if the Media item does not exist.
  """
  def get_media_item!(id), do: Repo.get!(MediaItem, id)

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
  Deletes a media_item and its associated tasks.

  Returns {:ok, %MediaItem{}} | {:error, %Ecto.Changeset{}}.
  """
  def delete_media_item(%MediaItem{} = media_item) do
    Tasks.delete_tasks_for(media_item)
    Repo.delete(media_item)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking media_item changes.
  """
  def change_media_item(%MediaItem{} = media_item, attrs \\ %{}) do
    MediaItem.changeset(media_item, attrs)
  end
end
