defmodule Pinchflat.Lifecycle.UserScripts.CommandRunnerTest do
  use ExUnit.Case, async: false

  alias Pinchflat.Utils.FilesystemUtils
  alias Pinchflat.Lifecycle.UserScripts.CommandRunner, as: Runner

  setup do
    FilesystemUtils.write_p!(filepath(), "")
    File.chmod(filepath(), 0o755)

    :ok
  end

  describe "run/2" do
    test "runs the provided lifecycle file if present" do
      # We *love* indirectly testing side effects
      tmp_dir = Application.get_env(:pinchflat, :tmpfile_directory)
      File.write(filepath(), "#!/bin/bash\ntouch #{tmp_dir}/test_file\n")

      refute File.exists?("#{tmp_dir}/test_file")
      assert :ok = Runner.run(:media_downloaded, %{})
      assert File.exists?("#{tmp_dir}/test_file")
    end

    test "passes the event name to the script" do
      tmp_dir = Application.get_env(:pinchflat, :tmpfile_directory)
      File.write(filepath(), "#!/bin/bash\necho $1 > #{tmp_dir}/event_name\n")

      assert :ok = Runner.run(:media_downloaded, %{})
      assert File.read!("#{tmp_dir}/event_name") == "media_downloaded\n"
    end

    test "passes the encoded data to the script" do
      tmp_dir = Application.get_env(:pinchflat, :tmpfile_directory)
      File.write(filepath(), "#!/bin/bash\necho $2 > #{tmp_dir}/encoded_data\n")

      assert :ok = Runner.run(:media_downloaded, %{foo: "bar"})
      assert File.read!("#{tmp_dir}/encoded_data") == "{\"foo\":\"bar\"}\n"
    end

    test "does nothing if the lifecycle file is not present" do
      :ok = File.rm(filepath())

      assert :ok = Runner.run(:media_downloaded, %{})
    end

    test "does nothing if the lifecycle file is empty" do
      File.write(filepath(), "")

      assert :ok = Runner.run(:media_downloaded, %{})
    end

    test "returns :ok if the command exits with a non-zero status" do
      File.write(filepath(), "#!/bin/bash\nexit 1\n")

      assert :ok = Runner.run(:media_downloaded, %{})
    end

    test "gets upset if you pass an invalid event type" do
      assert_raise ArgumentError, "Invalid event type: :invalid_event", fn ->
        Runner.run(:invalid_event, %{})
      end
    end

    test "gets upset if the record cannot be decoded" do
      File.write(filepath(), "#!/bin/bash")

      assert_raise MatchError, fn ->
        Runner.run(:media_downloaded, %Ecto.Changeset{})
      end
    end
  end

  defp filepath do
    base_dir = Application.get_env(:pinchflat, :extras_directory)

    Path.join([base_dir, "user-scripts", "lifecycle"])
  end
end
