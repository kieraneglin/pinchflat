defmodule Pinchflat.TasksTest do
  use Pinchflat.DataCase
  import Pinchflat.JobFixtures
  import Pinchflat.TasksFixtures
  import Pinchflat.MediaSourceFixtures

  alias Pinchflat.Tasks
  alias Pinchflat.Tasks.Task
  alias Pinchflat.JobFixtures.TestJobWorker

  @invalid_attrs %{job_id: nil}

  describe "schema" do
    test "it deletes a task when the job gets deleted" do
      task = Repo.preload(task_fixture(), [:job])

      {:ok, _} = Repo.delete(task.job)

      assert_raise Ecto.NoResultsError, fn -> Repo.reload!(task) end
    end

    test "it does not delete the other record when a job gets deleted" do
      task = Repo.preload(task_fixture(), [:channel, :job])

      {:ok, _} = Repo.delete(task.job)

      assert Repo.reload!(task.channel)
    end
  end

  describe "list_tasks/0" do
    test "it returns all tasks" do
      task = task_fixture()
      assert Tasks.list_tasks() == [task]
    end
  end

  describe "list_tasks_for/3" do
    test "it lets you specify which record type/ID to join on" do
      task = task_fixture()

      assert Tasks.list_tasks_for(:channel_id, task.channel_id) == [task]
    end

    test "it lets you specify which job states to include" do
      task = task_fixture()

      assert Tasks.list_tasks_for(:channel_id, task.channel_id, [:available]) == [task]
      assert Tasks.list_tasks_for(:channel_id, task.channel_id, [:cancelled]) == []
    end
  end

  describe "list_pending_tasks_for/2" do
    test "it lists pending tasks" do
      task = task_fixture()

      assert Tasks.list_pending_tasks_for(:channel_id, task.channel_id) == [task]
    end

    test "it does not list non-pending tasks" do
      task = Repo.preload(task_fixture(), :job)
      :ok = Oban.cancel_job(task.job)

      assert Tasks.list_pending_tasks_for(:channel_id, task.channel_id) == []
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

    test "accepts a job and channel" do
      job = job_fixture()
      channel = channel_fixture()

      assert {:ok, %Task{} = task} = Tasks.create_task(job, channel)

      assert task.job_id == job.id
      assert task.channel_id == channel.id
    end
  end

  describe "create_job_with_task/2" do
    test "it enqueues the given job" do
      channel = channel_fixture()

      refute_enqueued(worker: TestJobWorker)
      assert {:ok, %Task{}} = Tasks.create_job_with_task(TestJobWorker.new(%{}), channel)
      assert_enqueued(worker: TestJobWorker)
    end

    test "it creates a task record if successful" do
      channel = channel_fixture()

      assert {:ok, %Task{} = task} = Tasks.create_job_with_task(TestJobWorker.new(%{}), channel)

      assert task.channel_id == channel.id
    end

    test "it returns an error if the job fails to enqueue" do
      channel = channel_fixture()

      assert {:error, %Ecto.Changeset{}} = Tasks.create_job_with_task(%Ecto.Changeset{}, channel)
    end
  end

  describe "delete_task/1" do
    test "deletion deletes the task" do
      task = task_fixture()
      assert {:ok, %Task{}} = Tasks.delete_task(task)
      assert_raise Ecto.NoResultsError, fn -> Tasks.get_task!(task.id) end
    end

    test "deletion also cancels the attached job" do
      task = Repo.preload(task_fixture(), :job)

      assert {:ok, %Task{}} = Tasks.delete_task(task)
      job = Repo.reload!(task.job)

      assert job.state == "cancelled"
    end
  end

  describe "delete_tasks_for/1" do
    test "it deletes tasks attached to a channel" do
      channel = channel_fixture()
      task = task_fixture(channel_id: channel.id)

      assert :ok = Tasks.delete_tasks_for(channel)
      assert_raise Ecto.NoResultsError, fn -> Tasks.get_task!(task.id) end
    end
  end

  describe "delete_pending_tasks_for/1" do
    test "it deletes pending tasks attached to a channel" do
      channel = channel_fixture()
      task = task_fixture(channel_id: channel.id)

      assert :ok = Tasks.delete_pending_tasks_for(channel)
      assert_raise Ecto.NoResultsError, fn -> Tasks.get_task!(task.id) end
    end

    test "it does not delete non-pending tasks" do
      channel = channel_fixture()
      task = Repo.preload(task_fixture(channel_id: channel.id), :job)
      :ok = Oban.cancel_job(task.job)

      assert :ok = Tasks.delete_pending_tasks_for(channel)
      assert Tasks.get_task!(task.id)
    end
  end

  describe "change_task/1" do
    test "it returns a task changeset" do
      task = task_fixture()
      assert %Ecto.Changeset{} = Tasks.change_task(task)
    end
  end
end
