defmodule PinchflatWeb.Sources.SourceController do
  use PinchflatWeb, :controller

  alias Pinchflat.Repo
  alias Pinchflat.Media
  alias Pinchflat.Tasks
  alias Pinchflat.Sources
  alias Pinchflat.Profiles
  alias Pinchflat.Sources.Source

  def index(conn, _params) do
    sources = Repo.preload(Sources.list_sources(), :media_profile)

    render(conn, :index, sources: sources)
  end

  def new(conn, _params) do
    changeset = Sources.change_source(%Source{})

    render(conn, :new,
      changeset: changeset,
      media_profiles: media_profiles(),
      layout: get_onboarding_layout()
    )
  end

  def create(conn, %{"source" => source_params}) do
    case Sources.create_source(source_params) do
      {:ok, source} ->
        redirect_location =
          if Settings.get!(:onboarding), do: ~p"/?onboarding=1", else: ~p"/sources/#{source}"

        conn
        |> put_flash(:info, "Source created successfully.")
        |> redirect(to: redirect_location)

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :new,
          changeset: changeset,
          media_profiles: media_profiles(),
          layout: get_onboarding_layout()
        )
    end
  end

  def show(conn, %{"id" => id}) do
    source = Repo.preload(Sources.get_source!(id), :media_profile)

    pending_tasks = Repo.preload(Tasks.list_pending_tasks_for(:source_id, source.id), :job)
    pending_media = Media.list_pending_media_items_for(source, limit: 100)
    downloaded_media = Media.list_downloaded_media_items_for(source, limit: 100)

    render(conn, :show,
      source: source,
      pending_tasks: pending_tasks,
      pending_media: pending_media,
      downloaded_media: downloaded_media
    )
  end

  def edit(conn, %{"id" => id}) do
    source = Sources.get_source!(id)
    changeset = Sources.change_source(source)

    render(conn, :edit, source: source, changeset: changeset, media_profiles: media_profiles())
  end

  def update(conn, %{"id" => id, "source" => source_params}) do
    source = Sources.get_source!(id)

    case Sources.update_source(source, source_params) do
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

  def delete(conn, %{"id" => id} = params) do
    delete_files = Map.get(params, "delete_files", false)
    source = Sources.get_source!(id)
    {:ok, _source} = Sources.delete_source(source, delete_files: delete_files)

    flash_message =
      if delete_files do
        "Source and files deleted successfully."
      else
        "Source deleted successfully. Files were not deleted."
      end

    conn
    |> put_flash(:info, flash_message)
    |> redirect(to: ~p"/sources")
  end

  defp media_profiles do
    Profiles.list_media_profiles()
  end

  defp get_onboarding_layout do
    if Settings.get!(:onboarding) do
      {Layouts, :onboarding}
    else
      {Layouts, :app}
    end
  end
end
