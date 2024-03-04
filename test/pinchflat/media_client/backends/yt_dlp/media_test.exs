defmodule Pinchflat.MediaClient.Backends.YtDlp.MediaTest do
  use Pinchflat.DataCase
  import Mox

  alias Pinchflat.MediaClient.Backends.YtDlp.Media

  @media_url "https://www.youtube.com/watch?v=TiZPUDkDYbk"

  setup :verify_on_exit!

  # expect(YtDlpRunnerMock, :run, fn _url, [_, _, json_output_path | _] ->
  # copy_metadata(json_output_path)

  #   {:ok, ""}
  # end)

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
end
