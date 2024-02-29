defmodule Pinchflat.RepoTest do
  use Pinchflat.DataCase
  import Pinchflat.ProfilesFixtures

  alias Pinchflat.Repo
  alias Pinchflat.Profiles.MediaProfile
  alias Pinchflat.JobFixtures.TestJobWorker

  describe "insert_unique_job/1" do
    test "returns {:ok, job} if there is no conflict" do
      job = TestJobWorker.new(%{})

      assert {:ok, %Oban.Job{}} = Pinchflat.Repo.insert_unique_job(job)
    end

    test "returns {:duplicate, original_job} if there is a conflict" do
      job = TestJobWorker.new(%{foo: "bar"}, unique: [period: :infinity])

      {:ok, saved_job_1} = Pinchflat.Repo.insert_unique_job(job)

      assert {:duplicate, saved_job_2} = Pinchflat.Repo.insert_unique_job(job)
      assert saved_job_1.id == saved_job_2.id
    end

    test "returns the error if there is an error" do
      assert {:error, _} = Pinchflat.Repo.insert_unique_job(%Ecto.Changeset{})
    end
  end

  describe "maybe_limit/2" do
    test "applies a limit if provided" do
      media_profile_fixture()
      media_profile_fixture()

      result =
        MediaProfile
        |> Repo.maybe_limit(1)
        |> Repo.aggregate(:count, :id)

      assert result == 1
    end

    test "does not apply a limit if not provided" do
      media_profile_fixture()
      media_profile_fixture()

      result =
        MediaProfile
        |> Repo.maybe_limit(nil)
        |> Repo.aggregate(:count, :id)

      assert result == 2
    end
  end
end
