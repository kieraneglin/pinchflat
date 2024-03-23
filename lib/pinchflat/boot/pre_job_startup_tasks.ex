defmodule Pinchflat.Boot.PreJobStartupTasks do
  @moduledoc """
  This module is responsible for running startup tasks on app boot
  BEFORE the job runner has initiallized.

  It's a GenServer because that plays REALLY nicely with the existing
  Phoenix supervision tree.
  """

  # restart: :temporary means that this process will never be restarted (ie: will run once and then die)
  use GenServer, restart: :temporary
  import Ecto.Query, warn: false
  require Logger

  alias Pinchflat.Repo
  alias Pinchflat.Settings
  alias Pinchflat.Sources.Source
  alias Pinchflat.Media.MediaItem
  alias Pinchflat.Filesystem.FilesystemHelpers

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, %{}, opts)
  end

  @doc """
  Runs application startup tasks.

  Any code defined here will run every time the application starts. You must
  make sure that the code is idempotent and safe to run multiple times.

  This is a good place to set up default settings, create initial records, stuff like that.
  Should be fast - anything with the potential to be slow should be kicked off as a job instead.
  """
  @impl true
  def init(state) do
    apply_default_settings()
    backfill_uuids()
    ensure_directories_are_writeable()
    rename_old_job_workers()

    {:ok, state}
  end

  defp apply_default_settings do
    Settings.fetch!(:onboarding, true)
    Settings.fetch!(:pro_enabled, false)
  end

  defp backfill_uuids do
    # This is a one-time backfill to ensure that all media items have a UUID
    # This is important for the RSS feed and the streaming endpoint
    source_query = from(m in Source, where: is_nil(m.uuid), update: [set: [uuid: fragment("gen_random_uuid()")]])
    media_item_query = from(m in MediaItem, where: is_nil(m.uuid), update: [set: [uuid: fragment("gen_random_uuid()")]])

    {source_count, _} = Repo.update_all(source_query, [])
    {media_item_count, _} = Repo.update_all(media_item_query, [])

    Logger.info("Backfilled UUIDs for #{source_count} sources.")
    Logger.info("Backfilled UUIDs for #{media_item_count} media items.")
  end

  defp ensure_directories_are_writeable do
    directories = [
      Application.get_env(:pinchflat, :media_directory),
      Application.get_env(:pinchflat, :tmpfile_directory),
      Application.get_env(:pinchflat, :metadata_directory)
    ]

    Enum.each(directories, fn dir ->
      file = Path.join([dir, ".keep"])

      # This will fail if the directory is not writeable, stopping boot
      FilesystemHelpers.write_p!(file, "")
    end)
  end

  # As part of a large refactor, I ended up moving a bunch of workers around. This
  # is a problem because the workers are stored in the database and the runner
  # will try to run the OLD jobs. This is also why these tasks run before the job
  # runner starts up.
  #
  # Can be removed after a few months (created: 2024-03-12)
  defp rename_old_job_workers do
    # [ [old_name, new_name], ...]
    rename_map = [
      ["Pinchflat.Workers.MediaIndexingWorker", "Pinchflat.FastIndexing.MediaIndexingWorker"],
      ["Pinchflat.Workers.MediaDownloadWorker", "Pinchflat.Downloading.MediaDownloadWorker"],
      ["Pinchflat.Workers.FastIndexingWorker", "Pinchflat.FastIndexing.FastIndexingWorker"],
      ["Pinchflat.Workers.MediaCollectionIndexingWorker", "Pinchflat.SlowIndexing.MediaCollectionIndexingWorker"],
      ["Pinchflat.Workers.DataBackfillWorker", "Pinchflat.Boot.DataBackfillWorker"]
    ]

    jobs_renamed =
      Enum.reduce(rename_map, 0, fn [old_name, new_name], acc ->
        {count, _} =
          Oban.Job
          |> where(worker: ^old_name)
          |> Repo.update_all(set: [worker: new_name])

        acc + count
      end)

    Logger.info("Renamed #{jobs_renamed} old job workers")
  end
end
