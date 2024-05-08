defmodule Pinchflat.Utils.XmlUtilsTest do
  use Pinchflat.DataCase

  alias Pinchflat.Utils.XmlUtils

  describe "safe/1" do
    test "escapes invalid characters" do
      assert XmlUtils.safe("hello' & <world>") == "hello&#39; &amp; &lt;world&gt;"
    end

    test "converts input to string" do
      assert XmlUtils.safe(42) == "42"
      assert XmlUtils.safe(nil) == ""
    end
  end
end
