defmodule Pinchflat.YtDlp.MediaTest do
  use Pinchflat.DataCase
  import Mox
  import Pinchflat.MediaFixtures

  alias Pinchflat.YtDlp.Media

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

      assert {:ok, %{"title" => "Pinchflat Example Video"}} =
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

        {:ok, media_attributes_return_fixture()}
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
      assert "%(.{id,title,was_live,webpage_url,description,aspect_ratio,duration,upload_date})j" ==
               Media.indexing_output_template()
    end
  end

  describe "response_to_struct/1" do
    test "transforms a response into a struct" do
      response = %{
        "id" => "TiZPUDkDYbk",
        "title" => "Trying to Wheelie Without the Rear Brake",
        "description" => "I'm not sure what I expected.",
        "webpage_url" => "https://www.youtube.com/watch?v=TiZPUDkDYbk",
        "was_live" => false,
        "aspect_ratio" => 1.0,
        "duration" => 60,
        "upload_date" => "20210101"
      }

      assert %Media{
               media_id: "TiZPUDkDYbk",
               title: "Trying to Wheelie Without the Rear Brake",
               description: "I'm not sure what I expected.",
               original_url: "https://www.youtube.com/watch?v=TiZPUDkDYbk",
               livestream: false,
               short_form_content: false,
               upload_date: Date.from_iso8601!("2021-01-01")
             } == Media.response_to_struct(response)
    end

    test "sets short_form_content to true if the URL contains /shorts/" do
      response = %{
        "webpage_url" => "https://www.youtube.com/shorts/TiZPUDkDYbk",
        "aspect_ratio" => 1.0,
        "duration" => 61,
        "upload_date" => "20210101"
      }

      assert %Media{short_form_content: true} = Media.response_to_struct(response)
    end

    test "sets short_form_content to true if the aspect ratio are duration are right" do
      response = %{
        "webpage_url" => "https://www.youtube.com/watch?v=TiZPUDkDYbk",
        "aspect_ratio" => 0.5,
        "duration" => 59,
        "upload_date" => "20210101"
      }

      assert %Media{short_form_content: true} = Media.response_to_struct(response)
    end

    test "sets short_form_content to false otherwise" do
      response = %{
        "webpage_url" => "https://www.youtube.com/watch?v=TiZPUDkDYbk",
        "aspect_ratio" => 1.0,
        "duration" => 61,
        "upload_date" => "20210101"
      }

      assert %Media{short_form_content: false} = Media.response_to_struct(response)
    end

    test "doesn't blow up if short form content-related fields are missing" do
      response = %{
        "webpage_url" => nil,
        "aspect_ratio" => nil,
        "duration" => nil
      }

      assert %Media{short_form_content: nil} = Media.response_to_struct(response)
    end

    test "parses the upload date" do
      response = %{
        "webpage_url" => "https://www.youtube.com/watch?v=TiZPUDkDYbk",
        "aspect_ratio" => 1.0,
        "duration" => 61,
        "upload_date" => "20210101"
      }

      expected_date = Date.from_iso8601!("2021-01-01")

      assert %Media{upload_date: ^expected_date} = Media.response_to_struct(response)
    end

    test "doesn't blow up if upload date is missing" do
      response = %{
        "webpage_url" => "https://www.youtube.com/watch?v=TiZPUDkDYbk",
        "aspect_ratio" => 1.0,
        "duration" => 61,
        "upload_date" => nil
      }

      assert %Media{upload_date: nil} = Media.response_to_struct(response)
    end
  end
end
