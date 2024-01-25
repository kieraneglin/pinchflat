defmodule Pinchflat.Tasks do
  @moduledoc """
  The Tasks context.
  """

  import Ecto.Query, warn: false
  alias Pinchflat.Repo

  alias Pinchflat.Tasks.Task

  @doc """
  Returns the list of tasks. Returns [%Task{}, ...]
  """
  def list_tasks do
    Repo.all(Task)
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

  @doc """
  Deletes a task. Returns {:ok, %Task{}} | {:error, %Ecto.Changeset{}}.
  """
  def delete_task(%Task{} = task) do
    Repo.delete(task)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking task changes.
  """
  def change_task(%Task{} = task, attrs \\ %{}) do
    Task.changeset(task, attrs)
  end
end
