defmodule Pinchflat.YtDlp.MediaTest do
  use Pinchflat.DataCase

  import Pinchflat.MediaFixtures

  alias Pinchflat.YtDlp.Media

  @media_url "https://www.youtube.com/watch?v=TiZPUDkDYbk"

  describe "download/3" do
    test "calls the backend runner with the expected arguments" do
      expect(YtDlpRunnerMock, :run, fn @media_url, :download, opts, ot, addl ->
        assert [:no_simulate] = opts
        assert "after_move:%()j" = ot
        assert addl == []

        {:ok, render_metadata(:media_metadata)}
      end)

      assert {:ok, _} = Media.download(@media_url)
    end

    test "passes along custom command args" do
      expect(YtDlpRunnerMock, :run, fn _url, :download, opts, _ot, _addl ->
        assert [:no_simulate, :custom_arg] = opts

        {:ok, "{}"}
      end)

      assert {:ok, _} = Media.download(@media_url, [:custom_arg])
    end

    test "passes along additional options" do
      expect(YtDlpRunnerMock, :run, fn _url, :download, _opts, _ot, addl ->
        assert [addl_arg: true] = addl

        {:ok, "{}"}
      end)

      assert {:ok, _} = Media.download(@media_url, [], addl_arg: true)
    end

    test "parses and returns the generated file as JSON" do
      expect(YtDlpRunnerMock, :run, fn _url, :download, _opts, _ot, _addl ->
        {:ok, render_metadata(:media_metadata)}
      end)

      assert {:ok, %{"title" => "Pinchflat Example Video"}} =
               Media.download(@media_url)
    end

    test "returns errors" do
      expect(YtDlpRunnerMock, :run, fn _url, :download, _opt, _ot, _addl ->
        {:error, "something"}
      end)

      assert {:error, "something"} = Media.download(@media_url)
    end
  end

  describe "get_downloadable_status/1" do
    test "returns :downloadable if the media was never live" do
      expect(YtDlpRunnerMock, :run, fn _url, :get_downloadable_status, _opts, _ot, _addl ->
        {:ok, Phoenix.json_library().encode!(%{"live_status" => "not_live"})}
      end)

      assert {:ok, :downloadable} = Media.get_downloadable_status(@media_url)
    end

    test "returns :downloadable if the media was live and has been processed" do
      expect(YtDlpRunnerMock, :run, fn _url, :get_downloadable_status, _opts, _ot, _addl ->
        {:ok, Phoenix.json_library().encode!(%{"live_status" => "was_live"})}
      end)

      assert {:ok, :downloadable} = Media.get_downloadable_status(@media_url)
    end

    test "returns :downloadable if the media's live_status is nil" do
      expect(YtDlpRunnerMock, :run, fn _url, :get_downloadable_status, _opts, _ot, _addl ->
        {:ok, Phoenix.json_library().encode!(%{"live_status" => nil})}
      end)

      assert {:ok, :downloadable} = Media.get_downloadable_status(@media_url)
    end

    test "returns :ignorable if the media is currently live" do
      expect(YtDlpRunnerMock, :run, fn _url, :get_downloadable_status, _opts, _ot, _addl ->
        {:ok, Phoenix.json_library().encode!(%{"live_status" => "is_live"})}
      end)

      assert {:ok, :ignorable} = Media.get_downloadable_status(@media_url)
    end

    test "returns :ignorable if the media is scheduled to be live" do
      expect(YtDlpRunnerMock, :run, fn _url, :get_downloadable_status, _opts, _ot, _addl ->
        {:ok, Phoenix.json_library().encode!(%{"live_status" => "is_upcoming"})}
      end)

      assert {:ok, :ignorable} = Media.get_downloadable_status(@media_url)
    end

    test "returns :ignorable if the media was live but hasn't been processed" do
      expect(YtDlpRunnerMock, :run, fn _url, :get_downloadable_status, _opts, _ot, _addl ->
        {:ok, Phoenix.json_library().encode!(%{"live_status" => "post_live"})}
      end)

      assert {:ok, :ignorable} = Media.get_downloadable_status(@media_url)
    end

    test "returns an error if the downloadable status can't be determined" do
      expect(YtDlpRunnerMock, :run, fn _url, :get_downloadable_status, _opts, _ot, _addl ->
        {:ok, Phoenix.json_library().encode!(%{"live_status" => "what_tha"})}
      end)

      assert {:error, "Unknown live status: what_tha"} = Media.get_downloadable_status(@media_url)
    end

    test "optionally accepts additional args" do
      expect(YtDlpRunnerMock, :run, fn _url, :get_downloadable_status, _opts, _ot, addl ->
        assert [addl_arg: true] = addl

        {:ok, Phoenix.json_library().encode!(%{"live_status" => "not_live"})}
      end)

      assert {:ok, :downloadable} = Media.get_downloadable_status(@media_url, addl_arg: true)
    end
  end

  describe "download_thumbnail/2" do
    test "calls the backend runner with the expected arguments" do
      expect(YtDlpRunnerMock, :run, fn @media_url, :download_thumbnail, opts, ot, _addl ->
        assert opts == [:no_simulate, :skip_download, :write_thumbnail, {:convert_thumbnail, "jpg"}]
        assert ot == "after_move:%()j"

        {:ok, ""}
      end)

      assert {:ok, _} = Media.download_thumbnail(@media_url)
    end

    test "passes along custom command args" do
      expect(YtDlpRunnerMock, :run, fn _url, :download_thumbnail, opts, _ot, _addl ->
        assert :custom_arg in opts

        {:ok, "{}"}
      end)

      assert {:ok, _} = Media.download_thumbnail(@media_url, [:custom_arg])
    end

    test "passes along additional options" do
      expect(YtDlpRunnerMock, :run, fn _url, :download_thumbnail, _opts, _ot, addl ->
        assert [addl_arg: true] = addl

        {:ok, "{}"}
      end)

      assert {:ok, _} = Media.download_thumbnail(@media_url, [], addl_arg: true)
    end

    test "returns errors" do
      expect(YtDlpRunnerMock, :run, fn _url, :download_thumbnail, _opt, _ot, _addl ->
        {:error, "something"}
      end)

      assert {:error, "something"} = Media.download_thumbnail(@media_url)
    end
  end

  describe "get_media_attributes/1" do
    test "returns a list of video attributes" do
      expect(YtDlpRunnerMock, :run, fn _url, :get_media_attributes, _opts, _ot, _addl ->
        {:ok, media_attributes_return_fixture()}
      end)

      assert {:ok, %{description: _, media_id: _, original_url: _, title: _, livestream: _}} =
               Media.get_media_attributes(@media_url)
    end

    test "it passes the expected default args" do
      expect(YtDlpRunnerMock, :run, fn _url, :get_media_attributes, opts, ot, _addl ->
        assert opts == [:simulate, :skip_download]
        assert ot == Media.indexing_output_template()

        {:ok, media_attributes_return_fixture()}
      end)

      assert {:ok, _} = Media.get_media_attributes(@media_url)
    end

    test "passes along additional command options" do
      expect(YtDlpRunnerMock, :run, fn _url, :get_media_attributes, opts, _ot, _addl ->
        assert [:simulate, :skip_download, :custom_arg] = opts
        {:ok, media_attributes_return_fixture()}
      end)

      assert {:ok, _} = Media.get_media_attributes(@media_url, [:custom_arg])
    end

    test "passes along additional options" do
      expect(YtDlpRunnerMock, :run, fn _url, :get_media_attributes, _opts, _ot, addl ->
        assert [addl_arg: true] = addl
        {:ok, media_attributes_return_fixture()}
      end)

      assert {:ok, _} = Media.get_media_attributes(@media_url, [], addl_arg: true)
    end

    test "returns the error straight through when the command fails" do
      expect(YtDlpRunnerMock, :run, fn _url, :get_media_attributes, _opts, _ot, _addl -> {:error, "Big issue", 1} end)

      assert {:error, "Big issue", 1} = Media.get_media_attributes(@media_url)
    end
  end

  describe "indexing_output_template/0" do
    test "contains all the greatest hits" do
      attrs =
        ~w(id title live_status original_url description aspect_ratio duration upload_date timestamp playlist_index filename)a

      formatted_attrs = "%(.{#{Enum.join(attrs, ",")}})j"

      assert formatted_attrs == Media.indexing_output_template()
    end
  end

  describe "response_to_struct/1" do
    test "transforms a response into a struct" do
      response = %{
        "id" => "TiZPUDkDYbk",
        "title" => "Trying to Wheelie Without the Rear Brake",
        "description" => "I'm not sure what I expected.",
        "original_url" => "https://www.youtube.com/watch?v=TiZPUDkDYbk",
        "live_status" => "not_live",
        "aspect_ratio" => 1.0,
        "duration" => 60,
        "upload_date" => "20210101",
        "timestamp" => 1_600_000_000,
        "playlist_index" => 1,
        "filename" => "TiZPUDkDYbk.mp4"
      }

      assert %Media{
               media_id: "TiZPUDkDYbk",
               title: "Trying to Wheelie Without the Rear Brake",
               description: "I'm not sure what I expected.",
               original_url: "https://www.youtube.com/watch?v=TiZPUDkDYbk",
               livestream: false,
               short_form_content: false,
               uploaded_at: ~U[2020-09-13 12:26:40Z],
               duration_seconds: 60,
               playlist_index: 1,
               predicted_media_filepath: "TiZPUDkDYbk.mp4"
             } == Media.response_to_struct(response)
    end

    test "sets short_form_content to true if the URL contains /shorts/" do
      response = %{
        "original_url" => "https://www.youtube.com/shorts/TiZPUDkDYbk",
        "aspect_ratio" => 1.0,
        "duration" => 61,
        "upload_date" => "20210101"
      }

      assert %Media{short_form_content: true} = Media.response_to_struct(response)
    end

    test "sets short_form_content to true if the aspect ratio are duration are right" do
      response = %{
        "original_url" => "https://www.youtube.com/watch?v=TiZPUDkDYbk",
        "aspect_ratio" => 0.5,
        "duration" => 150,
        "upload_date" => "20210101"
      }

      assert %Media{short_form_content: true} = Media.response_to_struct(response)
    end

    test "sets short_form_content to false otherwise" do
      response = %{
        "original_url" => "https://www.youtube.com/watch?v=TiZPUDkDYbk",
        "aspect_ratio" => 1.0,
        "duration" => 61,
        "upload_date" => "20210101"
      }

      assert %Media{short_form_content: false} = Media.response_to_struct(response)
    end

    test "doesn't blow up if short form content-related fields are missing" do
      response = %{
        "original_url" => nil,
        "aspect_ratio" => nil,
        "duration" => nil,
        "upload_date" => "20210101"
      }

      assert %Media{short_form_content: nil} = Media.response_to_struct(response)
    end

    test "parses the duration" do
      response = %{
        "original_url" => "https://www.youtube.com/watch?v=TiZPUDkDYbk",
        "aspect_ratio" => 1.0,
        "duration" => 60.4,
        "upload_date" => "20210101"
      }

      assert %Media{duration_seconds: 60} = Media.response_to_struct(response)
    end

    test "doesn't blow up if duration is missing" do
      response = %{
        "original_url" => "https://www.youtube.com/watch?v=TiZPUDkDYbk",
        "aspect_ratio" => 1.0,
        "duration" => nil,
        "upload_date" => "20210101"
      }

      assert %Media{duration_seconds: nil} = Media.response_to_struct(response)
    end

    test "sets livestream to false if the live_status field isn't present" do
      response = %{
        "original_url" => "https://www.youtube.com/watch?v=TiZPUDkDYbk",
        "aspect_ratio" => 1.0,
        "duration" => 60,
        "upload_date" => "20210101"
      }

      assert %Media{livestream: false} = Media.response_to_struct(response)
    end

    test "doesn't blow up if playlist_index is missing" do
      response = %{
        "original_url" => "https://www.youtube.com/watch?v=TiZPUDkDYbk",
        "aspect_ratio" => 1.0,
        "duration" => nil,
        "upload_date" => "20210101"
      }

      assert %Media{playlist_index: 0} = Media.response_to_struct(response)
    end
  end

  describe "response_to_struct/1 when testing uploaded_at" do
    test "parses the upload date from the timestamp if present" do
      response = %{
        "original_url" => "https://www.youtube.com/watch?v=TiZPUDkDYbk",
        "aspect_ratio" => 1.0,
        "duration" => 61,
        "upload_date" => "20210101",
        "timestamp" => 1_600_000_000
      }

      expected_date = ~U[2020-09-13 12:26:40Z]

      assert %Media{uploaded_at: ^expected_date} = Media.response_to_struct(response)
    end

    test "parses the upload date from the uploaded_at if timestamp is present but nil" do
      response = %{
        "original_url" => "https://www.youtube.com/watch?v=TiZPUDkDYbk",
        "aspect_ratio" => 1.0,
        "duration" => 61,
        "upload_date" => "20210101",
        "timestamp" => nil
      }

      expected_date = ~U[2021-01-01 00:00:00Z]

      assert %Media{uploaded_at: ^expected_date} = Media.response_to_struct(response)
    end

    test "parses the upload date from the uploaded_at if timestamp absent" do
      response = %{
        "original_url" => "https://www.youtube.com/watch?v=TiZPUDkDYbk",
        "aspect_ratio" => 1.0,
        "duration" => 61,
        "upload_date" => "20210101"
      }

      expected_date = ~U[2021-01-01 00:00:00Z]

      assert %Media{uploaded_at: ^expected_date} = Media.response_to_struct(response)
    end

    test "doesn't blow up if upload date is missing" do
      response = %{
        "original_url" => "https://www.youtube.com/watch?v=TiZPUDkDYbk",
        "aspect_ratio" => 1.0,
        "duration" => 61,
        "upload_date" => nil
      }

      assert %Media{uploaded_at: nil} = Media.response_to_struct(response)
    end
  end
end
