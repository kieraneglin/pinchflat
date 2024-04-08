defmodule Pinchflat.Notifications.SourceNotificationsTest do
  use Pinchflat.DataCase

  import Mox
  import Pinchflat.MediaFixtures
  import Pinchflat.SourcesFixtures

  alias Pinchflat.Notifications.SourceNotifications

  @apprise_servers ["server_1", "server_2"]

  setup :verify_on_exit!

  describe "wrap_new_media_notification/3" do
    test "sends a notification when the pending count changes" do
      source = source_fixture()

      expect(AppriseRunnerMock, :run, fn servers, opts ->
        assert servers == @apprise_servers

        assert opts == [
                 title: "[Pinchflat] New media found!",
                 body: "Found 1 new media item(s) for #{source.custom_name}. Working on downloading them now!"
               ]

        {:ok, ""}
      end)

      SourceNotifications.wrap_new_media_notification(@apprise_servers, source, fn ->
        media_item_fixture(%{source_id: source.id, media_filepath: nil})
      end)
    end

    test "sends a notification when the downloaded count changes" do
      source = source_fixture()

      expect(AppriseRunnerMock, :run, fn servers, opts ->
        assert servers == @apprise_servers

        assert opts == [
                 title: "[Pinchflat] New media found!",
                 body: "Found 1 new media item(s) for #{source.custom_name}. Working on downloading them now!"
               ]

        {:ok, ""}
      end)

      SourceNotifications.wrap_new_media_notification(@apprise_servers, source, fn ->
        media_item_fixture(%{source_id: source.id, media_filepath: "file.mp4"})
      end)
    end

    test "does not send a notification when the count does not change" do
      source = source_fixture()

      expect(AppriseRunnerMock, :run, 0, fn _, _ -> {:ok, ""} end)

      SourceNotifications.wrap_new_media_notification(@apprise_servers, source, fn ->
        media_item_fixture(%{source_id: source.id, prevent_download: true, media_filepath: nil})
      end)
    end

    test "returns the value of the function" do
      source = source_fixture()
      expect(AppriseRunnerMock, :run, 0, fn _, _ -> {:ok, ""} end)

      retval = SourceNotifications.wrap_new_media_notification(@apprise_servers, source, fn -> "value" end)

      assert retval == "value"
    end
  end

  describe "send_new_media_notification/3" do
    test "sends a notification when count is positive" do
      source = source_fixture()

      expect(AppriseRunnerMock, :run, fn servers, opts ->
        assert servers == @apprise_servers

        assert opts == [
                 title: "[Pinchflat] New media found!",
                 body: "Found 1 new media item(s) for #{source.custom_name}. Working on downloading them now!"
               ]

        {:ok, ""}
      end)

      :ok = SourceNotifications.send_new_media_notification(@apprise_servers, source, 1)
    end

    test "does not send a notification when count not positive" do
      source = source_fixture()

      expect(AppriseRunnerMock, :run, 0, fn _, _ -> {:ok, ""} end)

      :ok = SourceNotifications.send_new_media_notification(@apprise_servers, source, 0)
      :ok = SourceNotifications.send_new_media_notification(@apprise_servers, source, -1)
    end
  end
end
