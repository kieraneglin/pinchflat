defmodule Pinchflat.Tasks do
  @moduledoc """
  The Tasks context.
  """

  import Ecto.Query, warn: false
  alias Pinchflat.Repo

  alias Pinchflat.Tasks.Task
  alias Pinchflat.Media.MediaItem
  alias Pinchflat.Sources.Source

  @doc """
  Returns the list of tasks. Returns [%Task{}, ...]
  """
  def list_tasks do
    Repo.all(Task)
  end

  @doc """
  Returns the list of tasks for a given record type and ID. Optionally allows you to specify
  which worker or job states to include.

  Returns [%Task{}, ...]
  """
  def list_tasks_for(attached_record_type, attached_record_id, worker_name \\ nil, job_states \\ Oban.Job.states()) do
    stringified_states = Enum.map(job_states, &to_string/1)

    worker_name_finder =
      if worker_name do
        # Workers are the full module name - we want to match on the string ENDING with
        # the passed worker name and it should be preceeded with a . so we aren't matching
        # on a substring. You can pass in more fragments of the worker name if you need
        # to disambiguate. eg: "TestWorker" or "FooBar.TestWorker"
        worker_finder = "%.#{worker_name}"

        dynamic([_t, j], fragment("? LIKE ?", j.worker, ^worker_finder))
      else
        true
      end

    Repo.all(
      from t in Task,
        join: j in assoc(t, :job),
        where: field(t, ^attached_record_type) == ^attached_record_id,
        where: ^worker_name_finder,
        where: j.state in ^stringified_states
    )
  end

  @doc """
  Returns the list of pending tasks for a given record type and ID. Optionally allows you to specify
  which worker to include.

  Returns [%Task{}, ...]
  """
  def list_pending_tasks_for(attached_record_type, attached_record_id, worker_name \\ nil) do
    list_tasks_for(
      attached_record_type,
      attached_record_id,
      worker_name,
      [:available, :scheduled, :retryable]
    )
  end

  @doc """
  Gets a single task.

  Returns %Task{}. Raises `Ecto.NoResultsError` if the Task does not exist.
  """
  def get_task!(id), do: Repo.get!(Task, id)

  @doc """
  Creates a task.

  Accepts map() | %Oban.Job{}, %Source{} | %Oban.Job{}, %MediaItem{}.
  Returns {:ok, %Task{}} | {:error, %Ecto.Changeset{}}.
  """
  def create_task(attrs) do
    %Task{}
    |> Task.changeset(attrs)
    |> Repo.insert()
  end

  # This function's signature is designed to help simplify
  # usage of `create_job_with_task/2`
  def create_task(%Oban.Job{} = job, attached_record) do
    attached_record_attr =
      case attached_record do
        %Source{} = source -> %{source_id: source.id}
        %MediaItem{} = media_item -> %{media_item_id: media_item.id}
      end

    %Task{}
    |> Task.changeset(Map.merge(%{job_id: job.id}, attached_record_attr))
    |> Repo.insert()
  end

  @doc """
  Creates a job from given attrs, creating a task with an attached record
  if successful. Returns an error if the job already exists.

  Returns {:ok, %Task{}} | {:error, :duplicate_job} | {:error, %Ecto.Changeset{}}.
  """
  def create_job_with_task(job_attrs, task_attached_record) do
    case Repo.insert_unique_job(job_attrs) do
      {:ok, job} -> create_task(job, task_attached_record)
      {:duplicate, _} -> {:error, :duplicate_job}
      err -> err
    end
  end

  @doc """
  Deletes a task. Also cancels any attached job.

  Returns {:ok, %Task{}} | {:error, %Ecto.Changeset{}}.
  """
  def delete_task(%Task{} = task) do
    :ok = Oban.cancel_job(task.job_id)

    Repo.delete(task)
  end

  @doc """
  Deletes all tasks attached to a given record, cancelling any attached jobs.
  Optionally allows you to specify which worker to include.

  Returns :ok
  """
  def delete_tasks_for(attached_record, worker_name \\ nil) do
    tasks =
      case attached_record do
        %Source{} = source -> list_tasks_for(:source_id, source.id, worker_name)
        %MediaItem{} = media_item -> list_tasks_for(:media_item_id, media_item.id, worker_name)
      end

    Enum.each(tasks, &delete_task/1)
  end

  @doc """
  Deletes all _pending_ tasks attached to a given record, cancelling any attached jobs.
  Optionally allows you to specify which worker to include.

  Returns :ok
  """
  def delete_pending_tasks_for(attached_record, worker_name \\ nil) do
    tasks =
      case attached_record do
        %Source{} = source -> list_pending_tasks_for(:source_id, source.id, worker_name)
        %MediaItem{} = media_item -> list_pending_tasks_for(:media_item_id, media_item.id, worker_name)
      end

    Enum.each(tasks, &delete_task/1)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking task changes.
  """
  def change_task(%Task{} = task, attrs \\ %{}) do
    Task.changeset(task, attrs)
  end
end
