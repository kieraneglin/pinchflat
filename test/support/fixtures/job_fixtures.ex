defmodule Pinchflat.JobFixtures do
  @moduledoc false

  defmodule TestJobWorker do
    @moduledoc false
    use Oban.Worker, queue: :default

    @impl Oban.Worker
    def perform(%Oban.Job{}) do
      :ok
    end
  end

  def job_fixture() do
    {:ok, job} = Oban.insert(TestJobWorker.new(%{}))

    job
  end
end
