defmodule Pinchflat.Profiles do
  @moduledoc """
  The Profiles context.
  """

  import Ecto.Query, warn: false

  alias Pinchflat.Repo
  alias Pinchflat.Sources
  alias Pinchflat.Profiles.MediaProfile

  @doc """
  Returns the list of media_profiles.

  Returns [%MediaProfile{}, ...]
  """
  def list_media_profiles do
    Repo.all(MediaProfile)
  end

  @doc """
  Gets a single media_profile.

  Returns %MediaProfile{}. Raises `Ecto.NoResultsError` if the Media profile does not exist.
  """
  def get_media_profile!(id), do: Repo.get!(MediaProfile, id)

  @doc """
  Creates a media_profile.

  Returns {:ok, %MediaProfile{}} | {:error, %Ecto.Changeset{}}
  """
  def create_media_profile(attrs) do
    %MediaProfile{}
    |> MediaProfile.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a media_profile.

  Returns {:ok, %MediaProfile{}} | {:error, %Ecto.Changeset{}}
  """
  def update_media_profile(%MediaProfile{} = media_profile, attrs) do
    media_profile
    |> MediaProfile.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a media_profile, all its sources, and all their media items.
  Can optionally delete the media files.

  Returns {:ok, %MediaProfile{}} | {:error, %Ecto.Changeset{}}
  """
  def delete_media_profile(%MediaProfile{} = media_profile, opts \\ []) do
    delete_files = Keyword.get(opts, :delete_files, false)

    media_profile
    |> Sources.list_sources_for()
    |> Enum.each(fn source ->
      Sources.delete_source(source, delete_files: delete_files)
    end)

    Repo.delete(media_profile)
  end

  @doc """
  Returns `%Ecto.Changeset{}`
  """
  def change_media_profile(%MediaProfile{} = media_profile, attrs \\ %{}) do
    MediaProfile.changeset(media_profile, attrs)
  end
end
