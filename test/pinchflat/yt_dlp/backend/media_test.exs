defmodule Pinchflat.YtDlp.Backend.MediaTest do
  use Pinchflat.DataCase
  import Mox
  import Pinchflat.MediaFixtures

  alias Pinchflat.YtDlp.Backend.Media

  @media_url "https://www.youtube.com/watch?v=TiZPUDkDYbk"

  setup :verify_on_exit!

  describe "download/2" do
    test "it calls the backend runner with the expected arguments" do
      expect(YtDlpRunnerMock, :run, fn @media_url, opts, ot ->
        assert [:no_simulate] = opts
        assert "after_move:%()j" = ot

        {:ok, render_metadata(:media_metadata)}
      end)

      assert {:ok, _} = Media.download(@media_url)
    end

    test "it passes along additional options" do
      expect(YtDlpRunnerMock, :run, fn _url, opts, _ot ->
        assert [:no_simulate, :custom_arg] = opts

        {:ok, "{}"}
      end)

      assert {:ok, _} = Media.download(@media_url, [:custom_arg])
    end

    test "it parses and returns the generated file as JSON" do
      expect(YtDlpRunnerMock, :run, fn _url, _opts, _ot ->
        {:ok, render_metadata(:media_metadata)}
      end)

      assert {:ok, %{"title" => "Trying to Wheelie Without the Rear Brake"}} =
               Media.download(@media_url)
    end

    test "it returns errors" do
      expect(YtDlpRunnerMock, :run, fn _url, _opt, _ot ->
        {:error, "something"}
      end)

      assert {:error, "something"} = Media.download(@media_url)
    end
  end

  describe "get_media_attributes/1" do
    test "returns a list of video attributes" do
      expect(YtDlpRunnerMock, :run, fn _url, _opts, _ot ->
        {:ok, media_attributes_return_fixture()}
      end)

      assert {:ok, %{description: _, media_id: _, original_url: _, title: _, livestream: _}} =
               Media.get_media_attributes(@media_url)
    end

    test "it passes the expected default args" do
      expect(YtDlpRunnerMock, :run, fn _url, opts, ot ->
        assert opts == [:simulate, :skip_download]
        assert ot == Media.indexing_output_template()

        {:ok, "{}"}
      end)

      assert {:ok, _} = Media.get_media_attributes(@media_url)
    end

    test "returns the error straight through when the command fails" do
      expect(YtDlpRunnerMock, :run, fn _url, _opts, _ot -> {:error, "Big issue", 1} end)

      assert {:error, "Big issue", 1} = Media.get_media_attributes(@media_url)
    end
  end

  describe "indexing_output_template/0" do
    test "contains all the greatest hits" do
      assert "%(.{id,title,was_live,original_url,description})j" ==
               Media.indexing_output_template()
    end
  end
end
