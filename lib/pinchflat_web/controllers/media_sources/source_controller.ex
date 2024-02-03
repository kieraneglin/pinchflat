defmodule PinchflatWeb.MediaSources.SourceController do
  use PinchflatWeb, :controller

  alias Pinchflat.Profiles
  alias Pinchflat.MediaSource
  alias Pinchflat.MediaSource.Source

  def index(conn, _params) do
    sources = MediaSource.list_sources()

    render(conn, :index, sources: sources)
  end

  def new(conn, _params) do
    changeset = MediaSource.change_source(%Source{})

    render(conn, :new, changeset: changeset, media_profiles: media_profiles())
  end

  def create(conn, %{"source" => source_params}) do
    case MediaSource.create_source(source_params) do
      {:ok, source} ->
        conn
        |> put_flash(:info, "Source created successfully.")
        |> redirect(to: ~p"/media_sources/sources/#{source}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :new, changeset: changeset, media_profiles: media_profiles())
    end
  end

  def show(conn, %{"id" => id}) do
    source = MediaSource.get_source!(id)

    render(conn, :show, source: source)
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
        |> redirect(to: ~p"/media_sources/sources/#{source}")

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
    |> redirect(to: ~p"/media_sources/sources")
  end

  defp media_profiles do
    Profiles.list_media_profiles()
  end
end
