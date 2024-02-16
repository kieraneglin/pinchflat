defmodule PinchflatWeb.MediaSources.SourceController do
  use PinchflatWeb, :controller

  alias Pinchflat.Repo
  alias Pinchflat.Media
  alias Pinchflat.Profiles
  alias Pinchflat.MediaSource
  alias Pinchflat.MediaSource.Source

  def index(conn, _params) do
    sources = Repo.preload(MediaSource.list_sources(), :media_profile)

    render(conn, :index, sources: sources)
  end

  def new(conn, _params) do
    changeset = MediaSource.change_source(%Source{})

    if get_session(conn, :onboarding) do
      render(conn, :new,
        changeset: changeset,
        media_profiles: media_profiles(),
        onboarding: true,
        layout: {Layouts, :onboarding}
      )
    else
      render(conn, :new, changeset: changeset, media_profiles: media_profiles(), onboarding: false)
    end
  end

  def create(conn, %{"source" => source_params}) do
    case MediaSource.create_source(source_params) do
      {:ok, source} ->
        redirect_location =
          if get_session(conn, :onboarding), do: ~p"/", else: ~p"/sources/#{source}"

        conn
        |> put_flash(:info, "Source created successfully.")
        |> redirect(to: redirect_location)

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :new, changeset: changeset, media_profiles: media_profiles())
    end
  end

  def show(conn, %{"id" => id}) do
    source =
      id
      |> MediaSource.get_source!()
      |> Repo.preload(:media_profile)

    pending_media = Media.list_pending_media_items_for(source)
    downloaded_media = Media.list_downloaded_media_items_for(source)

    render(conn, :show, source: source, pending_media: pending_media, downloaded_media: downloaded_media)
  end

  def edit(conn, %{"id" => id}) do
    source = MediaSource.get_source!(id)
    changeset = MediaSource.change_source(source)

    render(conn, :edit, source: source, changeset: changeset, media_profiles: media_profiles())
  end

  def update(conn, %{"id" => id, "source" => source_params}) do
    source = MediaSource.get_source!(id)

    case MediaSource.update_source(source, source_params) do
      {:ok, source} ->
        conn
        |> put_flash(:info, "Source updated successfully.")
        |> redirect(to: ~p"/sources/#{source}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :edit,
          source: source,
          changeset: changeset,
          media_profiles: media_profiles()
        )
    end
  end

  def delete(conn, %{"id" => id}) do
    source = MediaSource.get_source!(id)
    {:ok, _source} = MediaSource.delete_source(source)

    conn
    |> put_flash(:info, "Source deleted successfully.")
    |> redirect(to: ~p"/sources")
  end

  defp media_profiles do
    Profiles.list_media_profiles()
  end
end
