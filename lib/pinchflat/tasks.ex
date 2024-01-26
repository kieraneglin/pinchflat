defmodule Pinchflat.Tasks do
  @moduledoc """
  The Tasks context.
  """

  import Ecto.Query, warn: false
  alias Pinchflat.Repo

  alias Pinchflat.Tasks.Task
  alias Pinchflat.MediaSource.Channel

  @doc """
  Returns the list of tasks. Returns [%Task{}, ...]
  """
  def list_tasks do
    Repo.all(Task)
  end

  @doc """
  Returns the list of tasks for a given record type and ID. Optionally allows you to specify
  which job states to include.

  Returns [%Task{}, ...]
  """
  def list_tasks_for(attached_record_type, attached_record_id, job_states \\ Oban.Job.states()) do
    stringified_states = Enum.map(job_states, &to_string/1)

    Repo.all(
      from t in Task,
        join: j in assoc(t, :job),
        where: field(t, ^attached_record_type) == ^attached_record_id,
        where: j.state in ^stringified_states
    )
  end

  @doc """
  Returns the list of pending tasks for a given record type and ID.

  Returns [%Task{}, ...]
  """
  def list_pending_tasks_for(attached_record_type, attached_record_id) do
    list_tasks_for(
      attached_record_type,
      attached_record_id,
      [:available, :scheduled, :retryable]
    )
  end

  @doc """
  Gets a single task.

  Returns %Task{}. Raises `Ecto.NoResultsError` if the Task does not exist.
  """
  def get_task!(id), do: Repo.get!(Task, id)

  @doc """
  Creates a task. Returns {:ok, %Task{}} | {:error, %Ecto.Changeset{}}.
  """
  def create_task(attrs \\ %{}) do
    %Task{}
    |> Task.changeset(attrs)
    |> Repo.insert()
  end

  # This one's function signature is designed to help simplify
  # usage of `create_job_with_task/2`
  def create_task(%Oban.Job{} = job, %Channel{} = channel) do
    %Task{}
    |> Task.changeset(%{job_id: job.id, channel_id: channel.id})
    |> Repo.insert()
  end

  @doc """
  Creates a job from given attrs, creating a task with an attached record
  if successful.

  Returns {:ok, %Task{}} | {:error, %Ecto.Changeset{}}.
  """
  def create_job_with_task(job_attrs, task_attached_record) do
    case Oban.insert(job_attrs) do
      {:ok, job} -> create_task(job, task_attached_record)
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

  Returns :ok
  """
  def delete_tasks_for(%Channel{} = channel) do
    tasks = list_tasks_for(:channel_id, channel.id)

    Enum.each(tasks, fn task ->
      delete_task(task)
    end)
  end

  @doc """
  Deletes all _pending_ tasks attached to a given record, cancelling any attached jobs.

  Returns :ok
  """
  def delete_pending_tasks_for(%Channel{} = channel) do
    tasks = list_pending_tasks_for(:channel_id, channel.id)

    Enum.each(tasks, fn task ->
      delete_task(task)
    end)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking task changes.
  """
  def change_task(%Task{} = task, attrs \\ %{}) do
    Task.changeset(task, attrs)
  end
end
