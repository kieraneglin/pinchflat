defmodule PinchflatWeb.MediaProfiles.MediaProfileController do
  use PinchflatWeb, :controller
  use Pinchflat.Sources.SourcesQuery

  alias Pinchflat.Repo
  alias Pinchflat.Profiles
  alias Pinchflat.Profiles.MediaProfile
  alias Pinchflat.Profiles.MediaProfileDeletionWorker

  def index(conn, _params) do
    media_profiles =
      MediaProfile
      |> where([mp], is_nil(mp.marked_for_deletion_at))
      |> order_by(asc: :name)
      |> Repo.all()

    render(conn, :index, media_profiles: media_profiles)
  end

  def new(conn, _params) do
    changeset = Profiles.change_media_profile(%MediaProfile{})

    render(conn, :new, changeset: changeset, layout: get_onboarding_layout())
  end

  def create(conn, %{"media_profile" => media_profile_params}) do
    case Profiles.create_media_profile(media_profile_params) do
      {:ok, media_profile} ->
        redirect_location =
          if Settings.get!(:onboarding), do: ~p"/?onboarding=1", else: ~p"/media_profiles/#{media_profile}"

        conn
        |> put_flash(:info, "Media profile created successfully.")
        |> redirect(to: redirect_location)

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :new, changeset: changeset, layout: get_onboarding_layout())
    end
  end

  def show(conn, %{"id" => id}) do
    media_profile = Profiles.get_media_profile!(id)

    sources =
      SourcesQuery.new()
      |> where(^SourcesQuery.for_media_profile(media_profile))
      |> order_by(asc: :custom_name)
      |> Repo.all()

    render(conn, :show, media_profile: media_profile, sources: sources)
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

  def delete(conn, %{"id" => id} = params) do
    # This awkward comparison converts the string to a boolean
    delete_files = Map.get(params, "delete_files", "") == "true"
    media_profile = Profiles.get_media_profile!(id)

    {:ok, _} = Profiles.update_media_profile(media_profile, %{marked_for_deletion_at: DateTime.utc_now()})
    MediaProfileDeletionWorker.kickoff(media_profile, %{delete_files: delete_files})

    conn
    |> put_flash(:info, "Media Profile deletion started. This may take a while to complete.")
    |> redirect(to: ~p"/media_profiles")
  end

  defp get_onboarding_layout do
    if Settings.get!(:onboarding) do
      {Layouts, :onboarding}
    else
      {Layouts, :app}
    end
  end
end
