defmodule PinchflatWeb.Sources.SourceController do
  use PinchflatWeb, :controller

  import Ecto.Query, warn: false

  alias Pinchflat.Repo
  alias Pinchflat.Tasks
  alias Pinchflat.Sources
  alias Pinchflat.MediaQuery
  alias Pinchflat.Sources.Source
  alias Pinchflat.Media.MediaQuery
  alias Pinchflat.Profiles.MediaProfile
  alias Pinchflat.Downloading.DownloadingHelpers
  alias Pinchflat.SlowIndexing.SlowIndexingHelpers

  def index(conn, _params) do
    sources =
      Source
      |> order_by(asc: :custom_name)
      |> Repo.all()
      |> Repo.preload(:media_profile)

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

    pending_tasks =
      source
      |> Tasks.list_tasks_for(nil, [:executing, :available, :scheduled, :retryable])
      |> Repo.preload(:job)

    pending_media =
      MediaQuery.new()
      |> MediaQuery.for_source(source)
      |> MediaQuery.with_media_pending_download()
      |> order_by(desc: :id)
      |> limit(100)
      |> Repo.all()

    downloaded_media =
      MediaQuery.new()
      |> MediaQuery.for_source(source)
      |> MediaQuery.with_media_filepath()
      |> order_by(desc: :id)
      |> limit(100)
      |> Repo.all()

    render(conn, :show,
      source: source,
      pending_tasks: pending_tasks,
      pending_media: pending_media,
      downloaded_media: downloaded_media,
      total_downloaded: total_downloaded_for(source)
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

  def force_download(conn, %{"source_id" => id}) do
    source = Sources.get_source!(id)
    DownloadingHelpers.enqueue_pending_download_tasks(source)

    conn
    |> put_flash(:info, "Forced download of pending media items.")
    |> redirect(to: ~p"/sources/#{source}")
  end

  def force_index(conn, %{"source_id" => id}) do
    source = Sources.get_source!(id)
    SlowIndexingHelpers.kickoff_indexing_task(source, %{force: true})

    conn
    |> put_flash(:info, "Index enqueued.")
    |> redirect(to: ~p"/sources/#{source}")
  end

  defp media_profiles do
    MediaProfile
    |> order_by(asc: :name)
    |> Repo.all()
  end

  defp total_downloaded_for(source) do
    MediaQuery.new()
    |> MediaQuery.for_source(source)
    |> MediaQuery.with_media_filepath()
    |> Repo.aggregate(:count, :id)
  end

  defp get_onboarding_layout do
    if Settings.get!(:onboarding) do
      {Layouts, :onboarding}
    else
      {Layouts, :app}
    end
  end
end
