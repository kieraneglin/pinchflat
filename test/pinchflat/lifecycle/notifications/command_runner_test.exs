defmodule Pinchflat.Lifecycle.Notifications.CommandRunnerTest do
  use ExUnit.Case, async: false

  alias Pinchflat.Lifecycle.Notifications.CommandRunner, as: Runner

  @original_executable Application.compile_env(:pinchflat, :apprise_executable)

  setup do
    on_exit(&reset_executable/0)
  end

  describe "run/2" do
    test "returns :ok when the command succeeds" do
      assert {:ok, _} = Runner.run("server_1", [])
    end

    test "includes the servers as the first argument" do
      assert {:ok, output} = Runner.run(["server_1", "server_2"], [])

      assert String.contains?(output, "server_1 server_2")
    end

    test "lets you pass a single server as a string" do
      assert {:ok, output} = Runner.run("server_1", [])

      assert String.contains?(output, "server_1")
    end

    test "passes all arguments to the command" do
      assert {:ok, output} = Runner.run("server_1", ["--dry-run"])

      assert String.contains?(output, "--dry-run")
    end

    test "returns the output when the command fails" do
      wrap_executable("/bin/false", fn ->
        assert {:error, ""} = Runner.run("server_1", [])
      end)
    end

    test "returns a relevant error if no servers are provided" do
      assert {:error, :no_servers} = Runner.run(nil, [])
      assert {:error, :no_servers} = Runner.run("", [])
      assert {:error, :no_servers} = Runner.run([], [])
    end
  end

  describe "version/0" do
    test "adds the version arg" do
      assert {:ok, output} = Runner.version()

      assert String.contains?(output, "--version")
    end
  end

  defp wrap_executable(new_executable, fun) do
    Application.put_env(:pinchflat, :apprise_executable, new_executable)
    fun.()
    reset_executable()
  end

  def reset_executable do
    Application.put_env(:pinchflat, :apprise_executable, @original_executable)
  end
end
