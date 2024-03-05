defmodule Pinchflat.Utils.FilesystemUtils.FileFollowerServerTest do
  use ExUnit.Case, async: true

  alias alias Pinchflat.Utils.FilesystemUtils
  alias Pinchflat.Utils.FilesystemUtils.FileFollowerServer

  setup do
    {:ok, pid} = FileFollowerServer.start_link()
    tmpfile = FilesystemUtils.generate_metadata_tmpfile(:txt)

    {:ok, %{pid: pid, tmpfile: tmpfile}}
  end

  describe "watch_file" do
    test "calls the handler for each existing line in the file", %{pid: pid, tmpfile: tmpfile} do
      File.write!(tmpfile, "line1\nline2")
      parent = self()

      handler = fn line -> send(parent, line) end
      FileFollowerServer.watch_file(pid, tmpfile, handler)

      assert_receive "line1\n"
      assert_receive "line2"
    end

    test "calls the handler for each new line in the file", %{pid: pid, tmpfile: tmpfile} do
      parent = self()
      file = File.open!(tmpfile, [:append])
      handler = fn line -> send(parent, line) end

      FileFollowerServer.watch_file(pid, tmpfile, handler)

      IO.binwrite(file, "line1\n")
      assert_receive "line1\n"
      IO.binwrite(file, "line2")
      assert_receive "line2"
    end
  end

  describe "stop" do
    test "stops the watcher", %{pid: pid, tmpfile: tmpfile} do
      handler = fn _line -> :noop end
      FileFollowerServer.watch_file(pid, tmpfile, handler)

      refute is_nil(Process.info(pid))
      FileFollowerServer.stop(pid)
      # Gotta wait for the server to stop async
      :timer.sleep(10)
      assert is_nil(Process.info(pid))
    end
  end
end
