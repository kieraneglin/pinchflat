defmodule Pinchflat.Profiles.MediaProfileDeletionWorker do
  @moduledoc false

  use Oban.Worker,
    queue: :local_data,
    tags: ["media_profiles", "local_data"]

  require Logger

  alias __MODULE__
  alias Pinchflat.Profiles

  @doc """
  Starts the profile deletion worker. Does not attach it to a task like `kickoff_with_task/2`
  since deletion also cancels all tasks for the profile

  Returns {:ok, %Oban.Job{}} | {:error, %Ecto.Changeset{}}
  """
  def kickoff(profile, job_args \\ %{}, job_opts \\ []) do
    %{id: profile.id}
    |> Map.merge(job_args)
    |> MediaProfileDeletionWorker.new(job_opts)
    |> Oban.insert()
  end

  @doc """
  Deletes a profile and optionally deletes its files

  Returns :ok
  """
  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"id" => profile_id} = args}) do
    delete_files = Map.get(args, "delete_files", false)
    profile = Profiles.get_media_profile!(profile_id)

    Profiles.delete_media_profile(profile, delete_files: delete_files)
  end
end
