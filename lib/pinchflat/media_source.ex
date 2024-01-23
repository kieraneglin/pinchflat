defmodule Pinchflat.MediaSource do
  @moduledoc """
  The MediaSource context.
  """

  import Ecto.Query, warn: false
  alias Pinchflat.Repo

  alias Pinchflat.MediaSource.Channel

  @doc """
  Returns the list of channels. Returns [%Channel{}, ...]
  """
  def list_channels do
    Repo.all(Channel)
  end

  @doc """
  Gets a single channel.

  Returns %Channel{}. Raises `Ecto.NoResultsError` if the Channel does not exist.
  """
  def get_channel!(id), do: Repo.get!(Channel, id)

  @doc """
  Creates a channel. Returns {:ok, %Channel{}} | {:error, %Ecto.Changeset{}}
  """
  def create_channel(attrs \\ %{}) do
    %Channel{}
    |> Channel.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a channel. Returns {:ok, %Channel{}} | {:error, %Ecto.Changeset{}}
  """
  def update_channel(%Channel{} = channel, attrs) do
    channel
    |> Channel.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a channel. Returns {:ok, %Channel{}} | {:error, %Ecto.Changeset{}}
  """
  def delete_channel(%Channel{} = channel) do
    Repo.delete(channel)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking channel changes.
  """
  def change_channel(%Channel{} = channel, attrs \\ %{}) do
    Channel.changeset(channel, attrs)
  end
end
