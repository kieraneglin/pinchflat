defmodule Pinchflat.TasksTest do
  use Pinchflat.DataCase
  import Pinchflat.JobFixtures
  import Pinchflat.TasksFixtures

  alias Pinchflat.Tasks
  alias Pinchflat.Tasks.Task

  @invalid_attrs %{job_id: nil}

  describe "list_tasks/0" do
    test "it returns all tasks" do
      task = task_fixture()
      assert Tasks.list_tasks() == [task]
    end
  end

  describe "get_task!/1" do
    test "it returns the task with given id" do
      task = task_fixture()
      assert Tasks.get_task!(task.id) == task
    end
  end

  describe "create_task/1" do
    test "creation with valid data creates a task" do
      valid_attrs = %{job_id: job_fixture().id}

      assert {:ok, %Task{} = _task} = Tasks.create_task(valid_attrs)
    end

    test "creation with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Tasks.create_task(@invalid_attrs)
    end
  end

  describe "delete_task/1" do
    test "deletion deletes the task" do
      task = task_fixture()
      assert {:ok, %Task{}} = Tasks.delete_task(task)
      assert_raise Ecto.NoResultsError, fn -> Tasks.get_task!(task.id) end
    end
  end

  describe "change_task/1" do
    test "it returns a task changeset" do
      task = task_fixture()
      assert %Ecto.Changeset{} = Tasks.change_task(task)
    end
  end
end
