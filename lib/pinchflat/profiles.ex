defmodule Pinchflat.Profiles do
  @moduledoc """
  The Profiles context.
  """

  import Ecto.Query, warn: false
  alias Pinchflat.Repo

  alias Pinchflat.Profiles.MediaProfile

  @doc """
  Returns the list of media_profiles.

  ## Examples

      iex> list_media_profiles()
      [%MediaProfile{}, ...]

  """
  def list_media_profiles do
    Repo.all(MediaProfile)
  end

  @doc """
  Gets a single media_profile.

  Raises `Ecto.NoResultsError` if the Media profile does not exist.

  ## Examples

      iex> get_media_profile!(123)
      %MediaProfile{}

      iex> get_media_profile!(456)
      ** (Ecto.NoResultsError)

  """
  def get_media_profile!(id), do: Repo.get!(MediaProfile, id)

  @doc """
  Creates a media_profile.

  ## Examples

      iex> create_media_profile(%{field: value})
      {:ok, %MediaProfile{}}

      iex> create_media_profile(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_media_profile(attrs \\ %{}) do
    %MediaProfile{}
    |> MediaProfile.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a media_profile.

  ## Examples

      iex> update_media_profile(media_profile, %{field: new_value})
      {:ok, %MediaProfile{}}

      iex> update_media_profile(media_profile, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_media_profile(%MediaProfile{} = media_profile, attrs) do
    media_profile
    |> MediaProfile.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a media_profile.

  ## Examples

      iex> delete_media_profile(media_profile)
      {:ok, %MediaProfile{}}

      iex> delete_media_profile(media_profile)
      {:error, %Ecto.Changeset{}}

  """
  def delete_media_profile(%MediaProfile{} = media_profile) do
    Repo.delete(media_profile)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking media_profile changes.

  ## Examples

      iex> change_media_profile(media_profile)
      %Ecto.Changeset{data: %MediaProfile{}}

  """
  def change_media_profile(%MediaProfile{} = media_profile, attrs \\ %{}) do
    MediaProfile.changeset(media_profile, attrs)
  end
end
