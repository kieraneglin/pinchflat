defmodule PinchflatWeb.MediaProfiles.MediaProfileController do
  use PinchflatWeb, :controller

  alias Pinchflat.Profiles
  alias Pinchflat.Profiles.MediaProfile

  def index(conn, _params) do
    media_profiles = Profiles.list_media_profiles()
    render(conn, :index, media_profiles: media_profiles)
  end

  def new(conn, _params) do
    changeset = Profiles.change_media_profile(%MediaProfile{})
    render(conn, :new, changeset: changeset)
  end

  def create(conn, %{"media_profile" => media_profile_params}) do
    case Profiles.create_media_profile(media_profile_params) do
      {:ok, media_profile} ->
        conn
        |> put_flash(:info, "Media profile created successfully.")
        |> redirect(to: ~p"/media_profiles/#{media_profile}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :new, changeset: changeset)
    end
  end

  def show(conn, %{"id" => id}) do
    media_profile = Profiles.get_media_profile!(id)
    render(conn, :show, media_profile: media_profile)
  end

  def edit(conn, %{"id" => id}) do
    media_profile = Profiles.get_media_profile!(id)
    changeset = Profiles.change_media_profile(media_profile)
    render(conn, :edit, media_profile: media_profile, changeset: changeset)
  end

  def update(conn, %{"id" => id, "media_profile" => media_profile_params}) do
    media_profile = Profiles.get_media_profile!(id)

    case Profiles.update_media_profile(media_profile, media_profile_params) do
      {:ok, media_profile} ->
        conn
        |> put_flash(:info, "Media profile updated successfully.")
        |> redirect(to: ~p"/media_profiles/#{media_profile}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :edit, media_profile: media_profile, changeset: changeset)
    end
  end

  def delete(conn, %{"id" => id}) do
    media_profile = Profiles.get_media_profile!(id)
    {:ok, _media_profile} = Profiles.delete_media_profile(media_profile)

    conn
    |> put_flash(:info, "Media profile deleted successfully.")
    |> redirect(to: ~p"/media_profiles")
  end
end
