defmodule Pinchflat.Utils.FilesystemUtilsTest do
  use ExUnit.Case, async: true

  alias Pinchflat.Utils.FilesystemUtils

  describe "generate_metadata_tmpfile/1" do
    test "creates a tmpfile and returns its path" do
      res = FilesystemUtils.generate_metadata_tmpfile(:json)

      assert String.ends_with?(res, ".json")
      assert File.exists?(res)

      File.rm!(res)
    end
  end
end
