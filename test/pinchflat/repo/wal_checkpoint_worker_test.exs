defmodule Pinchflat.Repo.WalCheckpointWorkerTest do
  use Pinchflat.DataCase

  alias Pinchflat.Repo.WalCheckpointWorker

  describe "perform/1" do
    test "runs a checkpoint without raising" do
      assert :ok = perform_job(WalCheckpointWorker, %{})
    end
  end
end
