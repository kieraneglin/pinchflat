defmodule Pinchflat.TasksTest do
  use Pinchflat.DataCase
  import Pinchflat.JobFixtures
  import Pinchflat.TasksFixtures
  import Pinchflat.MediaFixtures
  import Pinchflat.SourcesFixtures

  alias Pinchflat.Tasks
  alias Pinchflat.Tasks.Task
  alias Pinchflat.JobFixtures.TestJobWorker

  @invalid_attrs %{job_id: nil}

  describe "schema" do
    test "deletes a task when the job gets deleted" do
      task = Repo.preload(task_fixture(), [:job])

      {:ok, _} = Repo.delete(task.job)

      assert_raise Ecto.NoResultsError, fn -> Repo.reload!(task) end
    end

    test "does not delete the other record when a job gets deleted" do
      task = Repo.preload(task_fixture(), [:source, :job])

      {:ok, _} = Repo.delete(task.job)

      assert Repo.reload!(task.source)
    end
  end

  describe "list_tasks/0" do
    test "returns all tasks" do
      task = task_fixture()
      assert Tasks.list_tasks() == [task]
    end
  end

  describe "list_tasks_for/3" do
    test "lets you specify which record type/ID to join on" do
      source = source_fixture()
      task = task_fixture(source_id: source.id)

      assert Tasks.list_tasks_for(source, nil, [:available]) == [task]
    end

    test "lets you specify which job states to include" do
      source = source_fixture()
      task = task_fixture(source_id: source.id)

      assert Tasks.list_tasks_for(source, nil, [:available]) == [task]
      assert Tasks.list_tasks_for(source, nil, [:cancelled]) == []
    end

    test "lets you specify which worker to include" do
      source = source_fixture()
      task = task_fixture(source_id: source.id)

      assert Tasks.list_tasks_for(source, "TestJobWorker") == [task]
      assert Tasks.list_tasks_for(source, "FooBarWorker") == []
    end

    test "includes all workers if no worker is specified" do
      source = source_fixture()
      task = task_fixture(source_id: source.id)

      assert Tasks.list_tasks_for(source, nil) == [task]
    end
  end

  describe "get_task!/1" do
    test "returns the task with given id" do
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

    test "accepts a job and source" do
      job = job_fixture()
      source = source_fixture()

      assert {:ok, %Task{} = task} = Tasks.create_task(job, source)

      assert task.job_id == job.id
      assert task.source_id == source.id
    end

    test "accepts a job and media item" do
      job = job_fixture()
      media_item = media_item_fixture()

      assert {:ok, %Task{} = task} = Tasks.create_task(job, media_item)

      assert task.job_id == job.id
      assert task.media_item_id == media_item.id
    end
  end

  describe "create_job_with_task/2" do
    test "enqueues the given job" do
      media_item = media_item_fixture()

      refute_enqueued(worker: TestJobWorker)
      assert {:ok, %Task{}} = Tasks.create_job_with_task(TestJobWorker.new(%{}), media_item)
      assert_enqueued(worker: TestJobWorker)
    end

    test "creates a task record if successful" do
      source = source_fixture()

      assert {:ok, %Task{} = task} = Tasks.create_job_with_task(TestJobWorker.new(%{}), source)

      assert task.source_id == source.id
    end

    test "returns an error if the job already exists" do
      source = source_fixture()
      job = TestJobWorker.new(%{foo: "bar"}, unique: [period: :infinity])

      assert {:ok, %Task{}} = Tasks.create_job_with_task(job, source)
      assert {:error, :duplicate_job} = Tasks.create_job_with_task(job, source)
    end

    test "returns an error if the job fails to enqueue" do
      source = source_fixture()

      assert {:error, %Ecto.Changeset{}} = Tasks.create_job_with_task(%Ecto.Changeset{}, source)
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

  describe "delete_tasks_for/2" do
    test "deletes tasks attached to a source" do
      source = source_fixture()
      task = task_fixture(source_id: source.id)

      assert :ok = Tasks.delete_tasks_for(source)
      assert_raise Ecto.NoResultsError, fn -> Tasks.get_task!(task.id) end
    end

    test "deletes the tasks attached to a media_item" do
      media_item = media_item_fixture()
      task = task_fixture(media_item_id: media_item.id)

      assert :ok = Tasks.delete_tasks_for(media_item)
      assert_raise Ecto.NoResultsError, fn -> Tasks.get_task!(task.id) end
    end

    test "deletion can specify which worker to include" do
      media_item = media_item_fixture()
      task = task_fixture(media_item_id: media_item.id)

      assert :ok = Tasks.delete_tasks_for(media_item, "FooBarWorker")
      assert Repo.reload!(task)

      assert :ok = Tasks.delete_tasks_for(media_item, "TestJobWorker")
      assert_raise Ecto.NoResultsError, fn -> Repo.reload!(task) end
    end

    test "deletion can specify which states to include" do
      source = source_fixture()
      task = task_fixture(source_id: source.id)

      assert :ok = Tasks.delete_tasks_for(source, nil, [:executing])
      assert Repo.reload!(task)

      assert :ok = Tasks.delete_tasks_for(source, nil, [:available])
      assert_raise Ecto.NoResultsError, fn -> Repo.reload!(task) end
    end

    test "deletion does not impact unintended records" do
      source = source_fixture()
      task = task_fixture(source_id: source.id)

      assert :ok = Tasks.delete_tasks_for(source_fixture())
      assert :ok = Tasks.delete_tasks_for(source_fixture(), "FooBarWorker")
      assert :ok = Tasks.delete_tasks_for(source_fixture(), "TestJobWorker")

      assert Repo.reload!(task)
    end
  end

  describe "delete_pending_tasks_for/1" do
    test "deletes pending tasks attached to a source" do
      source = source_fixture()
      task = task_fixture(source_id: source.id)

      assert :ok = Tasks.delete_pending_tasks_for(source)
      assert_raise Ecto.NoResultsError, fn -> Tasks.get_task!(task.id) end
    end

    test "does not delete non-pending tasks" do
      source = source_fixture()
      task = Repo.preload(task_fixture(source_id: source.id), :job)
      :ok = Oban.cancel_job(task.job)

      assert :ok = Tasks.delete_pending_tasks_for(source)
      assert Tasks.get_task!(task.id)
    end

    test "works on media_items" do
      media_item = media_item_fixture()
      pending_task = task_fixture(media_item_id: media_item.id)
      cancelled_task = Repo.preload(task_fixture(media_item_id: media_item.id), :job)
      :ok = Oban.cancel_job(cancelled_task.job)

      assert :ok = Tasks.delete_pending_tasks_for(media_item)
      assert Tasks.get_task!(cancelled_task.id)
      assert_raise Ecto.NoResultsError, fn -> Repo.reload!(pending_task) end
    end

    test "deletion can specify which worker to include" do
      media_item = media_item_fixture()
      task = task_fixture(media_item_id: media_item.id)

      assert :ok = Tasks.delete_pending_tasks_for(media_item, "FooBarWorker")
      assert Repo.reload!(task)

      assert :ok = Tasks.delete_pending_tasks_for(media_item, "TestJobWorker")
      assert_raise Ecto.NoResultsError, fn -> Repo.reload!(task) end
    end

    test "deletion can optionally include executing tasks" do
      source = source_fixture()
      task = task_fixture(source_id: source.id)

      from(Oban.Job, where: [id: ^task.job_id], update: [set: [state: "executing"]])
      |> Repo.update_all([])

      assert :ok = Tasks.delete_pending_tasks_for(source, nil, include_executing: false)
      assert Repo.reload!(task)
      assert :ok = Tasks.delete_pending_tasks_for(source, nil, include_executing: true)
      assert_raise Ecto.NoResultsError, fn -> Repo.reload!(task) end
    end
  end

  describe "change_task/1" do
    test "returns a task changeset" do
      task = task_fixture()
      assert %Ecto.Changeset{} = Tasks.change_task(task)
    end
  end
end
