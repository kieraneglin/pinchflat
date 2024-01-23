defmodule Pinchflat.MediaSource do
  @moduledoc """
  The MediaSource context.
  """

  import Ecto.Query, warn: false
  alias Pinchflat.Repo

  alias Pinchflat.MediaSource.Channel
  alias Pinchflat.MediaClient.ChannelDetails

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
  Creates a channel from a given Channel URL and additional attrs.

  Returns {:ok, %Channel{}} | {:error, %Ecto.Changeset{}} | {:error, binary()}

  IDEA: maybe instead of creating a channel from a URL, instead the form should
  extract details from the URL and automatically update based on that. So the
  actual submission would be a normal form object
  """
  def create_channel_from_url(channel_url, attrs) do
    case ChannelDetails.get_channel_details(channel_url) do
      {:ok, %ChannelDetails{} = channel_details} ->
        record_attrs =
          Map.merge(attrs, %{
            name: channel_details.name,
            channel_id: channel_details.id
          })

        create_channel(record_attrs)

      {:error, runner_error, _status_code} ->
        {:error, runner_error}
    end
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
