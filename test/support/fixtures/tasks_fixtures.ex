defmodule Pinchflat.TasksFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Pinchflat.Tasks` context.
  """

  alias Pinchflat.JobFixtures
  alias Pinchflat.MediaSourceFixtures

  @doc """
  Generate a task.
  """
  def task_fixture(attrs \\ %{}) do
    {:ok, task} =
      attrs
      |> Enum.into(%{
        channel_id: MediaSourceFixtures.channel_fixture().id,
        job_id: JobFixtures.job_fixture().id
      })
      |> Pinchflat.Tasks.create_task()

    task
  end
end
